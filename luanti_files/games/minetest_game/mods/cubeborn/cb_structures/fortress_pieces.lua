-- Nether fortress pieces, ported by tools/port_fortress.py from Mineclonia's
-- mcl_levelgen/fortress_bastion.lua (GPLv3, Mineclonia contributors; based on
-- Minecraft's NetherFortressGenerator); do not edit.
local A = cb_structures.piecegen
local N = cb_structures.fortress_nodes
local mathmin, mathmax, mathabs = math.min, math.max, math.abs
local insert = table.insert

------------------------------------------------------------------------
-- Nether Fortress pieces.
-- https://maven.fabricmc.net/docs/yarn-1.21.5+build.1/net/minecraft/structure/NetherFortressGenerator.html
------------------------------------------------------------------------

local cid_air = "air"


local cid_nether_bricks = N.nether_brick
local cid_nether_brick_stairs
	= N.nether_brick_stairs

local ipos3 = A.ipos3

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

local reorientate_coords = A.reorientate_coords
local set_block = A.set_block
local is_water_air_or_lava = A.is_water_air_or_lava
local is_ersatz = false

local function fill_area (piece, x1, y1, z1, x2, y2, z2, cid, param2)
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

local function build_foundation_column (x, y, z, level_min)
	if is_ersatz then
		-- `is_water_air_or_lava (x, y, z)' will prompt
		-- columns to be truncated when crossing chunk
		-- boundaries.
		while y > level_min do
			set_block (x, y, z, cid_nether_bricks, 0)
			y = y - 1
		end
	else
		while y > level_min + 1 do
			if not is_water_air_or_lava (x, y, z) then
				break
			end
			set_block (x, y, z, cid_nether_bricks, 0)
			y = y - 1
		end
	end
end

local function set_block_reorientated (piece, x, y, z, cid, param2)
	local x, y, z = reorientate_coords (piece, x, y, z)
	set_block (x, y, z, cid, param2)
end

local function P (piece_type, weight, limit, repeatable)
	return {
		piece_type = piece_type,
		weight = weight,
		limit = limit,
		repeatable = repeatable or false,
	}
end

local pieces, child_queue, count_placed, previous_piece_type

local ALL_BRIDGE_PIECES = {
	P ("bridge", 30, 0, true),
	P ("bridge_crossing", 10, 4),
	P ("bridge_small_crossing", 10, 4),
	P ("bridge_stairs", 10, 3),
	P ("bridge_platform", 5, 2),
	P ("corridor_exit", 5, 1),
}

local ALL_CORRIDOR_PIECES = {
	P ("small_corridor", 25, 0, true),
	P ("corridor_crossing", 15, 5),
	P ("corridor_right_turn", 5, 10),
	P ("corridor_left_turn", 5, 10),
	P ("corridor_stairs", 10, 3, true),
	P ("corridor_balcony", 7, 2),
	P ("corridor_nether_warts", 5, 2),
}

local function piece_basically_available_p (piece)
	return (piece.limit == 0
		or count_placed[piece.piece_type] < piece.limit)
end

local function piece_available_p (piece)
	return piece_basically_available_p (piece)
		and (piece.repeatable
		     or piece.piece_type ~= previous_piece_type)
end

local random_orientation = A.random_orientation
local make_rotated_bbox = A.make_rotated_bbox
local rotated_block_box = A.rotated_block_box
local any_collisions = A.any_collisions

local function produce_pieces (list)
	local have_limited = false
	local total = 0

	for _, piece in ipairs (list) do
		if piece.limit > 0
			and count_placed[piece.piece_type] < piece.limit then
			have_limited = true
		end
		if piece_basically_available_p (piece) then
			total = total + piece.weight
		end
	end
	return total, have_limited
end

local essay_bridge
local essay_bridge_crossing
local essay_bridge_small_crossing
local essay_bridge_stairs
local essay_bridge_platform
local essay_corridor_exit
local essay_small_corridor
local essay_corridor_crossing
local essay_corridor_right_turn
local essay_corridor_left_turn
local essay_corridor_stairs
local essay_corridor_balcony
local essay_corridor_nether_warts

local function instantiate_piece (piecetype, start, pieces,
				  rng, x, y, z, dir, depth)
	if piecetype == "bridge" then
		return essay_bridge (pieces, rng, x, y, z, dir, depth)
	elseif piecetype == "bridge_crossing" then
		return essay_bridge_crossing (pieces, x, y, z, dir, depth)
	elseif piecetype == "bridge_small_crossing" then
		return essay_bridge_small_crossing (pieces, x, y, z, dir, depth)
	elseif piecetype == "bridge_stairs" then
		return essay_bridge_stairs (pieces, x, y, z, dir, depth)
	elseif piecetype == "bridge_platform" then
		return essay_bridge_platform (pieces, x, y, z, dir, depth)
	elseif piecetype == "corridor_exit" then
		return essay_corridor_exit (pieces, rng, x, y, z, dir, depth)
	elseif piecetype == "small_corridor" then
		return essay_small_corridor (pieces, x, y, z, dir, depth)
	elseif piecetype == "corridor_crossing" then
		return essay_corridor_crossing (pieces, x, y, z, dir, depth)
	elseif piecetype == "corridor_right_turn" then
		return essay_corridor_right_turn (pieces, rng, x, y, z, dir, depth)
	elseif piecetype == "corridor_left_turn" then
		return essay_corridor_left_turn (pieces, rng, x, y, z, dir, depth)
	elseif piecetype == "corridor_stairs" then
		return essay_corridor_stairs (pieces, rng, x, y, z, dir, depth)
	elseif piecetype == "corridor_balcony" then
		return essay_corridor_balcony (pieces, x, y, z, dir, depth)
	elseif piecetype == "corridor_nether_warts" then
		return essay_corridor_nether_warts (pieces, x, y, z, dir, depth)
	end
	assert (false)
end


local function terminator_place (self, level, terrain, _, x1, z1, x2, z2)
	local rng = A.rng (self.seed)
	for dx = 0, 4 do
		for dy = 3, 4 do
			local lenz = rng:next_within (8)
			fill_area (self, dx, dy, 0, dx, dy, lenz, cid_nether_bricks, 0)
		end
	end

	local lenz = rng:next_within (8)
	fill_area (self, 0, 5, 0, 0, 5, lenz, cid_nether_bricks, 0)
	lenz = rng:next_within (8)
	fill_area (self, 4, 5, 0, 4, 5, lenz, cid_nether_bricks, 0)

	for dx = 0, 4 do
		local lenz = rng:next_within (5)
		fill_area (self, dx, 2, 0, dx, 2, lenz, cid_nether_bricks, 0)
	end

	for dx = 0, 4 do
		for dy = 0, 1 do
			local lenz = rng:next_within (3)
			fill_area (self, dx, dy, 0, dx, dy, lenz, cid_nether_bricks, 0)
		end
	end
end

local function place_terminator (rng, dir, x, y, z, depth)
	local bbox = rotated_block_box (x, y, z, -1, -3, 0, 5, 10, 8, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		-- print (string.format ("Terminator placed: %d, %d, %d", x, y, z))
		return {
			dir = dir,
			bbox = bbox,
			place = terminator_place,
			seed = rng:next_integer (),
			depth = depth,
		}
	-- elseif any_collisions (pieces, bbox) then
	-- 	print (A.first_collision (pieces, bbox), unpack (bbox))
	end
	return nil
end

local function generate_child_piece (start, parent, pieces, rng, x, y, z, dir,
				     depth, list)
	local total, have_limited = produce_pieces (list)

	if not have_limited then
		-- print (string.format ("Placing terminator: %d, %d, %d", x, y, z))
		return place_terminator (rng, dir, x, y, z, depth)
	end

	if total > 0 and depth <= 30 then
		for i = 1, 5 do
			local weight = rng:next_within (total)

			-- print ("Fortress attempt: " .. i .. ": " .. weight
			--        .. " (of total " .. total .. ")")
			-- print ("  Parent: " .. (parent.type or "unknown")
			--        .. " " .. tostring (parent)
			--        .. "; depth = " .. depth)

			for _, piece in ipairs (list) do
				if piece_basically_available_p (piece) then
					weight = weight - piece.weight
					if weight < 0 then
						if not piece_available_p (piece) then
							-- print ("  Piece unavailable: "
							--        .. piece.piece_type)
							break
						end

						local piecetype = piece.piece_type
						local piece = instantiate_piece (piecetype, start,
										 pieces,
										 rng, x, y, z,
										 dir, depth)
						-- print ("  Fortress attempt " .. i .. " yielded "
						--        .. piecetype .. " -> " .. tostring (piece))
						if piece then
							-- print (string.format ("  bbox = (%d,%d,%d) - (%d,%d,%d)",
							-- 		      unpack (piece.bbox)))
							piece.type = piecetype
							count_placed[piecetype]
								= count_placed[piecetype] + 1
							previous_piece_type = piecetype
							return piece
						end

						-- Proceed to make another attempt.
					end
				end
			end
		end
	end
	-- print (string.format ("Placing terminator: %d, %d, %d", x, y, z))
	return place_terminator (rng, dir, x, y, z, depth)
end

local function select_and_insert_child_piece (self, start, pieces, rng, x, y, z, dir,
					      corridor_p)
	local bbox = start.bbox
	local dmax = mathmax (mathabs (x - bbox[1]), mathabs (z - bbox[3]))
	if dmax <= 112 then
		local list = not corridor_p and ALL_BRIDGE_PIECES or ALL_CORRIDOR_PIECES
		local piece = generate_child_piece (start, self, pieces, rng, x, y, z,
						    dir, self.depth + 1, list)
		if piece then
			insert (pieces, piece)
			insert (child_queue, piece)
		end
		return piece
	else
		local bbox = rotated_block_box (x, y, z, -1, -3, 0, 5, 10, 8, dir)
		if bbox[2] > 10 and not any_collisions (pieces, bbox) then
			-- {
			-- 	dir = dir,
			-- 	bbox = bbox,
			-- 	place = terminator_place,
			-- 	seed = rng:next_integer (),
			-- }
			rng:next_integer () --- ???
		end
		return nil
	end
end

local function get_forward_pos (self, dx, dy)
	local dir = self.dir
	local bbox = self.bbox

	if dir == "north" then
		return bbox[1] + dx, bbox[2] + dy, bbox[3] - 1
	elseif dir == "south" then
		return bbox[1] + dx, bbox[2] + dy, bbox[6] + 1
	elseif dir == "west" then
		return bbox[1] - 1, bbox[2] + dy, bbox[3] + dx
	elseif dir == "east" then
		return bbox[4] + 1, bbox[2] + dy, bbox[3] + dx
	end
	assert (false)
end

local function fill_forward_opening (self, start, pieces, rng, dx, dy, corridor_p)
	local x, y, z = get_forward_pos (self, dx, dy)
	select_and_insert_child_piece (self, start, pieces, rng, x, y, z, self.dir,
				       corridor_p)
end

local function get_left_pos (self, dy, dz)
	local dir = self.dir
	local bbox = self.bbox

	if dir == "north" or dir == "south" then
		return bbox[1] - 1, bbox[2] + dy, bbox[3] + dz, "west"
	elseif dir == "west" or dir == "east" then
		return bbox[1] + dz, bbox[2] + dy, bbox[3] - 1, "north"
	end
	assert (false)
end

local function fill_left_opening (self, start, pieces, rng, dy, dz, corridor_p)
	local x, y, z, dir = get_left_pos (self, dy, dz)
	select_and_insert_child_piece (self, start, pieces, rng, x, y, z, dir,
				       corridor_p)
end

local function get_right_pos (self, dy, dz)
	local dir = self.dir
	local bbox = self.bbox

	if dir == "north" or dir == "south" then
		return bbox[4] + 1, bbox[2] + dy, bbox[3] + dz, "east"
	elseif dir == "west" or dir == "east" then
		return bbox[1] + dz, bbox[2] + dy, bbox[6] + 1, "south"
	end
	assert (false)
end

local function fill_right_opening (self, start, pieces, rng, dy, dz, corridor_p)
	local x, y, z, dir = get_right_pos (self, dy, dz)
	select_and_insert_child_piece (self, start, pieces, rng, x, y, z, dir,
				       corridor_p)
end

-- Bridge piece.

local cid_nether_brick_fence
	= N.nether_brick_fence

local function bridge_place (self, level, terrain, rng, x1, z1, x2, z2)
	-- Structure.
	fill_area (self, 0, 3, 0, 4, 4, 18, cid_nether_bricks, 0)
	fill_area (self, 0, 5, 0, 0, 5, 18, cid_nether_bricks, 0)
	fill_area (self, 4, 5, 0, 4, 5, 18, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 4, 2, 5, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 13, 4, 2, 18, cid_nether_bricks, 0)
	fill_area (self, 0, 0, 0, 4, 1, 3, cid_nether_bricks, 0)
	fill_area (self, 0, 0, 15, 4, 1, 18, cid_nether_bricks, 0)

	-- Passageway.
	fill_area (self, 1, 5, 0, 3, 7, 18, cid_air, 0)

	-- Supports.
	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 4, 0, 2) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)

		local x, y, z = reorientate_coords (self, dx, -1, 18 - dz)
		build_foundation_column (x, y, z, level_min)
	end

	-- Windows.
	fill_area (self, 0, 1, 1, 0, 4, 1, cid_nether_brick_fence, 0)
	fill_area (self, 0, 3, 4, 0, 4, 4, cid_nether_brick_fence, 0)
	fill_area (self, 0, 3, 14, 0, 4, 14, cid_nether_brick_fence, 0)
	fill_area (self, 0, 1, 17, 0, 4, 17, cid_nether_brick_fence, 0)
	fill_area (self, 4, 1, 1, 4, 4, 1, cid_nether_brick_fence, 0)
	fill_area (self, 4, 3, 4, 4, 4, 4, cid_nether_brick_fence, 0)
	fill_area (self, 4, 3, 14, 4, 4, 14, cid_nether_brick_fence, 0)
	fill_area (self, 4, 1, 17, 4, 4, 17, cid_nether_brick_fence, 0)
end

local function bridge_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 1, 3, false)
end

function essay_bridge (pieces, rng, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -1, -3, 0, 5, 10, 19, dir)
	-- print (string.format (" bridge bbox: %s (%d,%d,%d) - (%d,%d,%d)",
	-- 		      tostring (any_collisions (pieces,
	-- 						bbox)),
	-- 		      unpack (bbox)))
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			bbox = bbox,
			place = bridge_place,
			dir = dir,
			depth = depth,
			insert_children = bridge_insert_children,
		}
	end
	return nil
end

-- Bridge crossing piece.

local function bridge_crossing_place (self, level, terrain, rng, x1, z1, x2, z2)
	-- Crossing.
	fill_area (self, 7, 3, 0, 11, 4, 18, cid_nether_bricks, 0)
	fill_area (self, 0, 3, 7, 18, 4, 11, cid_nether_bricks, 0)
	fill_area (self, 8, 5, 0, 10, 7, 18, cid_air, 0)
	fill_area (self, 0, 5, 8, 18, 7, 10, cid_air, 0)
	fill_area (self, 7, 5, 0, 7, 5, 7, cid_nether_bricks, 0)
	fill_area (self, 7, 5, 11, 7, 5, 18, cid_nether_bricks, 0)
	fill_area (self, 11, 5, 0, 11, 5, 7, cid_nether_bricks, 0)
	fill_area (self, 11, 5, 11, 11, 5, 18, cid_nether_bricks, 0)
	fill_area (self, 0, 5, 7, 7, 5, 7, cid_nether_bricks, 0)
	fill_area (self, 11, 5, 7, 18, 5, 7, cid_nether_bricks, 0)
	fill_area (self, 0, 5, 11, 7, 5, 11, cid_nether_bricks, 0)
	fill_area (self, 11, 5, 11, 18, 5, 11, cid_nether_bricks, 0)
	fill_area (self, 7, 2, 0, 11, 2, 5, cid_nether_bricks, 0)
	fill_area (self, 7, 2, 13, 11, 2, 18, cid_nether_bricks, 0)
	fill_area (self, 7, 0, 0, 11, 1, 3, cid_nether_bricks, 0)
	fill_area (self, 7, 0, 15, 11, 1, 18, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 7, 5, 2, 11, cid_nether_bricks, 0)
	fill_area (self, 13, 2, 7, 18, 2, 11, cid_nether_bricks, 0)
	fill_area (self, 0, 0, 7, 3, 1, 11, cid_nether_bricks, 0)
	fill_area (self, 15, 0, 7, 18, 1, 11, cid_nether_bricks, 0)

	-- Foundation.

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (7, 0, 0, 11, 0, 2) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)

		local x, y, z = reorientate_coords (self, dx, -1, 18 - dz)
		build_foundation_column (x, y, z, level_min)
	end

	for dx, _, dz in ipos3 (0, 0, 7, 2, 0, 11) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)

		local x, y, z = reorientate_coords (self, 18 - dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function bridge_crossing_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 8, 3, false)
	fill_left_opening (self, start, pieces, rng, 3, 8, false)
	fill_right_opening (self, start, pieces, rng, 3, 8, false)
end

function essay_bridge_crossing (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -8, -3, 0, 19, 10, 19, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			bbox = bbox,
			place = bridge_crossing_place,
			dir = dir,
			depth = depth,
			insert_children = bridge_crossing_insert_children,
		}
	end
	return nil
end

local function create_initial_bridge_crossing (pieces, rng, x, z, dir, depth)
	return {
		dir = dir,
		depth = depth,
		bbox = make_rotated_bbox (x, 64, z, dir, 19, 10, 19),
		place = bridge_crossing_place,
		insert_children = bridge_crossing_insert_children,
	}
end

-- Bridge small crossing piece.

local function bridge_small_crossing_place (self, level, terrain, rng, x1, z1, x2, z2)
	-- Base, interior, and corners.
	fill_area (self, 0, 0, 0, 6, 1, 6, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 6, 7, 6, cid_air, 0)
	fill_area (self, 0, 2, 0, 1, 6, 0, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 6, 1, 6, 6, cid_nether_bricks, 0)
	fill_area (self, 5, 2, 0, 6, 6, 0, cid_nether_bricks, 0)
	fill_area (self, 5, 2, 6, 6, 6, 6, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 0, 6, 1, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 5, 0, 6, 6, cid_nether_bricks, 0)
	fill_area (self, 6, 2, 0, 6, 6, 1, cid_nether_bricks, 0)
	fill_area (self, 6, 2, 5, 6, 6, 6, cid_nether_bricks, 0)

	-- Arch.
	fill_area (self, 2, 6, 0, 4, 6, 0, cid_nether_bricks, 0)
	fill_area (self, 2, 6, 6, 4, 6, 6, cid_nether_bricks, 0)
	fill_area (self, 0, 6, 2, 0, 6, 4, cid_nether_bricks, 0)
	fill_area (self, 6, 6, 2, 6, 6, 4, cid_nether_bricks, 0)

	-- Arch decorations.
	fill_area (self, 2, 5, 0, 4, 5, 0, cid_nether_brick_fence, 0)
	fill_area (self, 2, 5, 6, 4, 5, 6, cid_nether_brick_fence, 0)
	fill_area (self, 0, 5, 2, 0, 5, 4, cid_nether_brick_fence, 0)
	fill_area (self, 6, 5, 2, 6, 5, 4, cid_nether_brick_fence, 0)

	-- Foundations.
	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 6, 0, 6) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function bridge_small_crossing_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 2, 0, false)
	fill_left_opening (self, start, pieces, rng, 0, 2, false)
	fill_right_opening (self, start, pieces, rng, 0, 2, false)
end

function essay_bridge_small_crossing (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -2, 0, 0, 7, 9, 7, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = bridge_small_crossing_place,
			insert_children = bridge_small_crossing_insert_children,
		}
	end
	return nil
end

-- Bridge stairs piece.

local function bridge_stairs_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 0, 0, 6, 1, 6, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 6, 10, 6, cid_air, 0)
	fill_area (self, 0, 2, 0, 1, 8, 0, cid_nether_bricks, 0)
	fill_area (self, 5, 2, 0, 6, 8, 0, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 1, 0, 8, 6, cid_nether_bricks, 0)
	fill_area (self, 6, 2, 1, 6, 8, 6, cid_nether_bricks, 0)
	fill_area (self, 1, 2, 6, 5, 8, 6, cid_nether_bricks, 0)

	fill_area (self, 0, 3, 2, 0, 5, 4, cid_nether_brick_fence, 0)
	fill_area (self, 6, 3, 2, 6, 5, 2, cid_nether_brick_fence, 0)
	fill_area (self, 6, 3, 4, 6, 5, 4, cid_nether_brick_fence, 0)

	set_block_reorientated (self, 5, 2, 5, cid_nether_bricks, 0)
	fill_area (self, 4, 2, 5, 4, 3, 5, cid_nether_bricks, 0)
	fill_area (self, 3, 2, 5, 3, 4, 5, cid_nether_bricks, 0)
	fill_area (self, 2, 2, 5, 2, 5, 5, cid_nether_bricks, 0)
	fill_area (self, 1, 2, 5, 1, 6, 5, cid_nether_bricks, 0)
	fill_area (self, 1, 7, 1, 5, 7, 4, cid_nether_bricks, 0)
	fill_area (self, 6, 8, 2, 6, 8, 4, cid_air, 0)
	fill_area (self, 2, 6, 0, 4, 8, 0, cid_nether_bricks, 0)
	fill_area (self, 2, 5, 0, 4, 5, 0, cid_nether_brick_fence, 0)

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 6, 0, 6) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function bridge_stairs_insert_children (self, start, pieces, rng, x, z)
	fill_right_opening (self, start, pieces, rng, 6, 2, false)
end

function essay_bridge_stairs (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -2, 0, 0, 7, 11, 7, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = bridge_stairs_place,
			insert_children = bridge_stairs_insert_children,
		}
	end
	return nil
end

-- Bridge platform piece (a.k.a. ``Monster Throne'').

local cid_mob_spawner = "cb_structures:blaze_spawner"

local function bridge_platform_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 2, 0, 6, 7, 7, cid_air, 0)

	-- Steps & rim.
	fill_area (self, 0, 5, 3, 0, 5, 8, cid_nether_bricks, 0)
	fill_area (self, 1, 0, 0, 5, 1, 7, cid_nether_bricks, 0)
	fill_area (self, 1, 2, 0, 1, 4, 2, cid_nether_bricks, 0)
	fill_area (self, 1, 2, 1, 5, 2, 7, cid_nether_bricks, 0)
	fill_area (self, 1, 3, 2, 5, 3, 7, cid_nether_bricks, 0)
	fill_area (self, 1, 4, 3, 5, 4, 7, cid_nether_bricks, 0)
	fill_area (self, 1, 5, 2, 1, 5, 3, cid_nether_bricks, 0)
	fill_area (self, 1, 5, 8, 5, 5, 8, cid_nether_bricks, 0)
	fill_area (self, 5, 2, 0, 5, 4, 2, cid_nether_bricks, 0)
	fill_area (self, 5, 5, 2, 5, 5, 3, cid_nether_bricks, 0)
	fill_area (self, 6, 5, 3, 6, 5, 8, cid_nether_bricks, 0)

	set_block_reorientated (self, 1, 6, 3, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 5, 6, 3, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 0, 6, 3, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 6, 6, 3, cid_nether_brick_fence, 0)

	-- Fences.
	fill_area (self, 0, 6, 4, 0, 6, 7, cid_nether_brick_fence, 0)
	fill_area (self, 1, 6, 8, 5, 6, 8, cid_nether_brick_fence, 0)
	fill_area (self, 2, 7, 8, 4, 7, 8, cid_nether_brick_fence, 0)
	fill_area (self, 6, 6, 4, 6, 6, 7, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 0, 6, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 1, 7, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 2, 8, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 3, 8, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 4, 8, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 5, 7, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 6, 6, 8, cid_nether_brick_fence, 0)

	-- Foundations.
	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 6, 0, 6) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end

	-- Spawner.
	local x, y, z = reorientate_coords (self, 3, 5, 5)
	set_block (x, y, z, cid_mob_spawner, 0)
	A.construct (x, y, z)
end

local function bridge_platform_insert_children (self, start, pieces, rng, x, z)
	-- Nothing here but crickets.
end

function essay_bridge_platform (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -2, 0, 0, 7, 8, 9, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = bridge_platform_place,
			insert_children = bridge_platform_insert_children,
		}
	end
	return nil
end

-- Corridor exit piece (a.k.a. ``Lava Well Room'').

local cid_nether_lava_source
	= "default:lava_source"

local function corridor_exit_common (self)
	-- Room and floor.
	fill_area (self, 0, 5, 0, 12, 13, 12, cid_air, 0)
	fill_area (self, 0, 3, 0, 12, 4, 12, cid_nether_bricks, 0)

	fill_area (self, 0, 5, 0, 1, 12, 12, cid_nether_bricks, 0)
	fill_area (self, 11, 5, 0, 12, 12, 12, cid_nether_bricks, 0)
	fill_area (self, 2, 5, 11, 4, 12, 12, cid_nether_bricks, 0)
	fill_area (self, 8, 5, 11, 10, 12, 12, cid_nether_bricks, 0)
	fill_area (self, 5, 9, 11, 7, 12, 12, cid_nether_bricks, 0)
	fill_area (self, 2, 5, 0, 4, 12, 1, cid_nether_bricks, 0)
	fill_area (self, 8, 5, 0, 10, 12, 1, cid_nether_bricks, 0)
	fill_area (self, 5, 9, 0, 7, 12, 1, cid_nether_bricks, 0)
	fill_area (self, 2, 11, 2, 10, 12, 10, cid_nether_bricks, 0)
	fill_area (self, 5, 8, 0, 7, 8, 0, cid_nether_bricks, 0)

	-- Fences.
	for dxz = 1, 11, 2 do
		-- Fence in wall.
		fill_area (self, dxz, 10, 0, dxz, 11, 0, cid_nether_brick_fence, 0)
		fill_area (self, dxz, 10, 12, dxz, 11, 12, cid_nether_brick_fence, 0)
		fill_area (self, 0, 10, dxz, 0, 11, dxz, cid_nether_brick_fence, 0)
		fill_area (self, 12, 10, dxz, 12, 11, dxz, cid_nether_brick_fence, 0)

		set_block_reorientated (self, dxz, 13, 0, cid_nether_bricks, 0)
		set_block_reorientated (self, dxz, 13, 12, cid_nether_bricks, 0)
		set_block_reorientated (self, 0, 13, dxz, cid_nether_bricks, 0)
		set_block_reorientated (self, 12, 13, dxz, cid_nether_bricks, 0)

		-- Hmm, this conditional appears not to exist in
		-- Minecraft without overruning the roof.
		if dxz < 11 then
			set_block_reorientated (self, dxz + 1, 13, 0,
						cid_nether_brick_fence, 0)
			set_block_reorientated (self, dxz + 1, 13, 12,
						cid_nether_brick_fence, 0)
			set_block_reorientated (self, 0, 13, dxz + 1,
						cid_nether_brick_fence, 0)
			set_block_reorientated (self, 12, 13, dxz + 1,
						cid_nether_brick_fence, 0)
		end
	end

	-- Fences by corners.
	set_block_reorientated (self, 0, 13, 0, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 12, 13, 0, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 0, 13, 12, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 12, 13, 12, cid_nether_brick_fence, 0)

	-- Sealed interior windows.
	for dz = 3, 9, 2 do
		fill_area (self, 1, 7, dz, 1, 8, dz, cid_nether_brick_fence, 0)
		fill_area (self, 11, 7, dz, 11, 8, dz, cid_nether_brick_fence, 0)
	end
end

local function corridor_exit_place (self, level, terrain, rng, x1, z1, x2, z2)
	corridor_exit_common (self)

	-- Connecting foundations.
	fill_area (self, 4, 2, 0, 8, 2, 12, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 4, 12, 2, 8, cid_nether_bricks, 0)
	fill_area (self, 4, 0, 0, 8, 1, 3, cid_nether_bricks, 0)
	fill_area (self, 4, 0, 9, 8, 1, 12, cid_nether_bricks, 0)
	fill_area (self, 0, 0, 4, 3, 1, 8, cid_nether_bricks, 0)
	fill_area (self, 9, 0, 4, 12, 1, 8, cid_nether_bricks, 0)

	-- Foundations.

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (4, 0, 0, 8, 0, 2) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
		local x, y, z = reorientate_coords (self, dx, -1, 12 - dz)
		build_foundation_column (x, y, z, level_min)
	end
	for dx, _, dz in ipos3 (0, 0, 4, 2, 0, 8) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
		local x, y, z = reorientate_coords (self, 12 - dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end

	-- Well.
	fill_area (self, 5, 5, 5, 7, 5, 7, cid_nether_bricks, 0)
	fill_area (self, 6, 1, 6, 6, 4, 6, cid_air, 0)

	-- Block diverting lava.
	set_block_reorientated (self, 6, 0, 6, cid_nether_bricks, 0)
	-- Lava.
	set_block_reorientated (self, 6, 5, 6, cid_nether_lava_source, 0)
end

local function corridor_exit_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 5, 3, true)
end

function essay_corridor_exit (pieces, rng, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -5, -3, 0, 13, 14, 13, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_exit_place,
			insert_children = corridor_exit_insert_children,
		}
	end
	return nil
end

-- Small corridor piece.

local function small_corridor_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 0, 0, 4, 1, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 4, 5, 4, cid_air, 0)

	fill_area (self, 0, 2, 0, 0, 5, 4, cid_nether_bricks, 0)
	fill_area (self, 4, 2, 0, 4, 5, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 6, 0, 4, 6, 4, cid_nether_bricks, 0)

	fill_area (self, 0, 3, 1, 0, 4, 1, cid_nether_brick_fence, 0)
	fill_area (self, 0, 3, 3, 0, 4, 3, cid_nether_brick_fence, 0)
	fill_area (self, 4, 3, 1, 4, 4, 1, cid_nether_brick_fence, 0)
	fill_area (self, 4, 3, 3, 4, 4, 3, cid_nether_brick_fence, 0)

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 4, 0, 4) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function small_corridor_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 1, 0, true)
end

function essay_small_corridor (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -1, 0, 0, 5, 7, 5, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = small_corridor_place,
			insert_children = small_corridor_insert_children,
		}
	end
	return nil
end

-- Corridor crossing piece.

local function corridor_crossing_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 0, 0, 4, 1, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 4, 5, 4, cid_air, 0)
	fill_area (self, 0, 2, 0, 0, 5, 0, cid_nether_bricks, 0)
	fill_area (self, 4, 2, 0, 4, 5, 0, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 4, 0, 5, 4, cid_nether_bricks, 0)
	fill_area (self, 4, 2, 4, 4, 5, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 6, 0, 4, 6, 4, cid_nether_bricks, 0)

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 4, 0, 4) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function corridor_crossing_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 1, 0, true)
	fill_left_opening (self, start, pieces, rng, 0, 1, true)
	fill_right_opening (self, start, pieces, rng, 0, 1, true)
end

function essay_corridor_crossing (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -1, 0, 0, 5, 7, 5, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_crossing_place,
			insert_children = corridor_crossing_insert_children,
		}
	end
	return nil
end

local cid_chest_small = "default:chest"
local set_loot_table = A.set_loot_table

-- Corridor right turn piece.

local function corridor_right_turn_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 0, 0, 4, 1, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 4, 5, 4, cid_air, 0)
	fill_area (self, 0, 2, 0, 0, 5, 4, cid_nether_bricks, 0)
	fill_area (self, 4, 2, 0, 4, 5, 0, cid_nether_bricks, 0)
	fill_area (self, 1, 2, 4, 4, 5, 4, cid_nether_bricks, 0)

	fill_area (self, 0, 3, 1, 0, 4, 1, cid_nether_bricks, 0)
	fill_area (self, 0, 3, 3, 0, 4, 3, cid_nether_bricks, 0)
	fill_area (self, 1, 3, 4, 1, 4, 4, cid_nether_bricks, 0)
	fill_area (self, 3, 3, 4, 3, 4, 4, cid_nether_bricks, 0)

	if self.chest then
		local x, y, z = reorientate_coords (self, 1, 2, 3)
		set_block (x, y, z, cid_chest_small, facedirs[self.dir])
		set_loot_table (x, y, z, rng, "nether_bridge")
	end

	fill_area (self, 0, 6, 0, 4, 6, 4, cid_nether_bricks, 0)
	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 4, 0, 4) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function corridor_right_turn_insert_children (self, start, pieces, rng, x, z)
	fill_right_opening (self, start, pieces, rng, 0, 1, true)
end

function essay_corridor_right_turn (pieces, rng, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -1, 0, 0, 5, 7, 5, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_right_turn_place,
			insert_children = corridor_right_turn_insert_children,
			chest = rng:next_within (3) == 0,
		}
	-- elseif any_collisions (pieces, bbox) then
	-- 	local collider = A.first_collision (pieces, bbox)
	-- 	print ("COLLISION: ", dump (bbox), collider)
	--	print ("COLLISION: ", dump (collider))
	end
	return nil
end

-- Corridor left turn piece.

local function corridor_left_turn_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 0, 0, 4, 1, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 4, 5, 4, cid_air, 0)
	fill_area (self, 4, 2, 0, 4, 5, 4, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 0, 5, 0, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 4, 3, 5, 4, cid_nether_bricks, 0)

	fill_area (self, 4, 3, 1, 4, 4, 1, cid_nether_brick_fence, 0)
	fill_area (self, 4, 3, 3, 4, 4, 3, cid_nether_brick_fence, 0)
	fill_area (self, 1, 3, 4, 1, 4, 4, cid_nether_brick_fence, 0)
	fill_area (self, 3, 3, 4, 3, 4, 4, cid_nether_brick_fence, 0)

	if self.chest then
		local x, y, z = reorientate_coords (self, 3, 2, 3)
		set_block (x, y, z, cid_chest_small, facedirs[self.dir])
		set_loot_table (x, y, z, rng, "nether_bridge")
	end

	fill_area (self, 0, 6, 0, 4, 6, 4, cid_nether_bricks, 0)
	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 4, 0, 4) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function corridor_left_turn_insert_children (self, start, pieces, rng, x, z)
	fill_left_opening (self, start, pieces, rng, 0, 1, true)
end

function essay_corridor_left_turn (pieces, rng, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -1, 0, 0, 5, 7, 5, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_left_turn_place,
			insert_children = corridor_left_turn_insert_children,
			chest = rng:next_within (3) == 0,
		}
	end
	return nil
end

-- Corridor stairs piece.

local function corridor_stairs_place (self, level, terrain, rng, x1, z1, x2, z2)
	local param2 = reverse_facedirs[self.dir]
	local windows = true
	local level_min = level.preset.min_y
	for dz = 0, 9 do
		local ybase = mathmax (1, 7 - dz)
		local yroof = mathmin (mathmax (ybase + 5, 14 - dz), 13)
		fill_area (self, 0, 0, dz, 4, ybase, dz, cid_nether_bricks, 0)
		fill_area (self, 1, ybase + 1, dz, 3, yroof - 1, dz, cid_air, 0)

		if dz < 7 then
			fill_area (self, 1, ybase + 1, dz, 3, ybase + 1, dz,
				   cid_nether_brick_stairs, param2)
		end

		fill_area (self, 0, yroof, dz, 4, yroof, dz, cid_nether_bricks, 0)
		fill_area (self, 0, ybase + 1, dz, 0, yroof - 1, dz, cid_nether_bricks, 0)
		fill_area (self, 4, ybase + 1, dz, 4, yroof - 1, dz, cid_nether_bricks, 0)
		if windows then
			fill_area (self, 0, ybase + 2, dz, 0, ybase + 3, dz,
				   cid_nether_brick_fence, 0)
			fill_area (self, 4, ybase + 2, dz, 4, ybase + 3, dz,
				   cid_nether_brick_fence, 0)
		end
		windows = not windows

		for dx = 0, 4 do
			local x, y, z = reorientate_coords (self, dx, -1, dz)
			build_foundation_column (x, y, z, level_min)
		end
	end
end

local function corridor_stairs_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 1, 0, true)
end

function essay_corridor_stairs (pieces, rng, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -1, -7, 0, 5, 14, 10, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_stairs_place,
			insert_children = corridor_stairs_insert_children,
		}
	end
	return nil
end

-- Corridor balcony piece.

local function corridor_balcony_place (self, level, terrain, rng, x1, z1, x2, z2)
	fill_area (self, 0, 0, 0, 8, 1, 8, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 0, 8, 5, 8, cid_air, 0)
	fill_area (self, 0, 2, 0, 2, 5, 0, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 4, 8, 2, 8, cid_nether_bricks, 0)
	fill_area (self, 0, 6, 0, 8, 6, 5, cid_nether_bricks, 0)
	fill_area (self, 6, 2, 0, 8, 5, 0, cid_nether_bricks, 0)

	fill_area (self, 1, 3, 0, 1, 4, 0, cid_nether_brick_fence, 0)
	fill_area (self, 1, 3, 8, 7, 3, 8, cid_nether_brick_fence, 0)
	fill_area (self, 7, 3, 0, 7, 4, 0, cid_nether_brick_fence, 0)

	fill_area (self, 1, 1, 4, 2, 2, 4, cid_air, 0)
	fill_area (self, 6, 1, 4, 7, 2, 4, cid_air, 0)

	set_block_reorientated (self, 0, 3, 8, cid_nether_brick_fence, 0)
	set_block_reorientated (self, 8, 3, 8, cid_nether_brick_fence, 0)

	fill_area (self, 0, 3, 6, 0, 3, 7, cid_nether_brick_fence, 0)
	fill_area (self, 1, 4, 5, 1, 5, 5, cid_nether_brick_fence, 0)
	fill_area (self, 7, 4, 5, 7, 5, 5, cid_nether_brick_fence, 0)
	fill_area (self, 8, 3, 6, 8, 3, 7, cid_nether_brick_fence, 0)

	fill_area (self, 0, 3, 4, 0, 5, 5, cid_nether_bricks, 0)
	fill_area (self, 1, 3, 5, 2, 5, 5, cid_nether_bricks, 0)
	fill_area (self, 6, 3, 5, 7, 5, 5, cid_nether_bricks, 0)
	fill_area (self, 8, 3, 4, 8, 5, 5, cid_nether_bricks, 0)

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (0, 0, 0, 5, 0, 8) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function corridor_balcony_insert_children (self, start, pieces, rng, x, z)
	local dir = self.dir

	if dir == "west" or dir == "north" then
		fill_left_opening (self, start, pieces, rng, 0, 5,
				   rng:next_within (8) ~= 0)
		fill_right_opening (self, start, pieces, rng, 0, 5,
				    rng:next_within (8) ~= 0)
	else
		fill_left_opening (self, start, pieces, rng, 0, 1,
				   rng:next_within (8) ~= 0)
		fill_right_opening (self, start, pieces, rng, 0, 1,
				    rng:next_within (8) ~= 0)
	end
end

function essay_corridor_balcony (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -3, 0, 0, 9, 7, 9, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_balcony_place,
			insert_children = corridor_balcony_insert_children,
		}
	end
	return nil
end

-- Corridor nether warts piece.

local cid_nether_wart_0
	= N.nether_wart
local cid_soul_sand
	= N.soul_sand

local function corridor_nether_warts_place (self, level, terrain, rng, x1, z1, x2, z2)
	corridor_exit_common (self)

	-- Stairwell.
	local dir = self.dir
	local param2 = facedirs[dir]

	for step = 0, 6 do
		local dz = step + 4
		local dy = step + 5

		--- Stairs should extend to the floor for the first 4
		--- blocks but any deeper and their supports must be
		--- elevated in order that they may not obstruct the
		--- rear exit.

		for dx = 5, 7 do
			set_block_reorientated (self, dx, dy, dz,
						cid_nether_brick_stairs, param2)
		end

		if step > 0 and step < 5 then
			fill_area (self, 5, 5, dz, 7, dy - 1, dz, cid_nether_bricks, 0)
		else
			fill_area (self, 5, 8, dz, 7, dy - 1, dz, cid_nether_bricks, 0)
		end

		if step > 1 then
			fill_area (self, 5, step + 6, dz, 7, step + 9, dz, cid_air, 0)
		end
	end

	fill_area (self, 5, 12, 11, 7, 12, 11, cid_nether_brick_stairs, param2)
	fill_area (self, 5, 6, 7, 5, 7, 7, cid_nether_brick_fence, 0)
	fill_area (self, 7, 6, 7, 7, 7, 7, cid_nether_brick_fence, 0)
	fill_area (self, 5, 13, 12, 7, 13, 12, cid_air, 0)

	-- Basin rim.
	fill_area (self, 2, 5, 2, 3, 5, 3, cid_nether_bricks, 0)
	fill_area (self, 2, 5, 9, 3, 5, 10, cid_nether_bricks, 0)
	fill_area (self, 2, 5, 4, 2, 5, 8, cid_nether_bricks, 0)
	fill_area (self, 9, 5, 2, 10, 5, 3, cid_nether_bricks, 0)
	fill_area (self, 9, 5, 9, 10, 5, 10, cid_nether_bricks, 0)
	fill_area (self, 10, 5, 4, 10, 5, 8, cid_nether_bricks, 0)

	local param2 = left_facedirs[dir]
	set_block_reorientated (self, 4, 5, 2, cid_nether_brick_stairs, param2)
	set_block_reorientated (self, 4, 5, 3, cid_nether_brick_stairs, param2)
	set_block_reorientated (self, 4, 5, 9, cid_nether_brick_stairs, param2)
	set_block_reorientated (self, 4, 5, 10, cid_nether_brick_stairs, param2)

	local param2 = right_facedirs[dir]
	set_block_reorientated (self, 8, 5, 2, cid_nether_brick_stairs, param2)
	set_block_reorientated (self, 8, 5, 3, cid_nether_brick_stairs, param2)
	set_block_reorientated (self, 8, 5, 9, cid_nether_brick_stairs, param2)
	set_block_reorientated (self, 8, 5, 10, cid_nether_brick_stairs, param2)

	-- Netherwort i.e. nether ``wart''...
	fill_area (self, 3, 4, 4, 4, 4, 8, cid_soul_sand, 0)
	fill_area (self, 8, 4, 4, 9, 4, 8, cid_soul_sand, 0)
	fill_area (self, 3, 5, 4, 4, 5, 8, cid_nether_wart_0, 3)
	fill_area (self, 8, 5, 4, 9, 5, 8, cid_nether_wart_0, 3)

	-- Supports.
	fill_area (self, 4, 2, 0, 8, 2, 12, cid_nether_bricks, 0)
	fill_area (self, 0, 2, 4, 12, 2, 8, cid_nether_bricks, 0)
	fill_area (self, 4, 0, 0, 8, 1, 3, cid_nether_bricks, 0)
	fill_area (self, 4, 0, 9, 8, 1, 12, cid_nether_bricks, 0)
	fill_area (self, 0, 0, 4, 3, 1, 8, cid_nether_bricks, 0)
	fill_area (self, 9, 0, 4, 12, 1, 8, cid_nether_bricks, 0)

	-- Foundations.

	local level_min = level.preset.min_y
	for dx, _, dz in ipos3 (4, 0, 0, 8, 0, 2) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
		local x, y, z = reorientate_coords (self, dx, -1, 12 - dz)
		build_foundation_column (x, y, z, level_min)
	end
	for dx, _, dz in ipos3 (0, 0, 4, 2, 0, 8) do
		local x, y, z = reorientate_coords (self, dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
		local x, y, z = reorientate_coords (self, 12 - dx, -1, dz)
		build_foundation_column (x, y, z, level_min)
	end
end

local function corridor_nether_warts_insert_children (self, start, pieces, rng, x, z)
	fill_forward_opening (self, start, pieces, rng, 5, 3, true)
	fill_forward_opening (self, start, pieces, rng, 5, 11, true)
end

function essay_corridor_nether_warts (pieces, x, y, z, dir, depth)
	local bbox = rotated_block_box (x, y, z, -5, -3, 0, 13, 14, 13, dir)
	if bbox[2] > 10 and not any_collisions (pieces, bbox) then
		return {
			dir = dir,
			depth = depth,
			bbox = bbox,
			place = corridor_nether_warts_place,
			insert_children = corridor_nether_warts_insert_children,
		}
	end
	return nil
end

-- Start piece.

local function insert_start_piece (pieces, rng, x, z)
	local piece = create_initial_bridge_crossing (pieces, rng, x, z,
						      random_orientation (rng), 0)
	insert (pieces, piece)
	return piece
end

local bbox_from_pieces = A.bbox_from_pieces
local bbox_height = A.bbox_height
local translate_vertically = A.translate_vertically

-- https://maven.fabricmc.net/docs/yarn-1.21.5+build.1/net/minecraft/structure/StructurePiecesCollector.html#shiftInto(net.minecraft.util.math.random.Random,int,int)

local function fortress_shift_into (rng, pieces, base_y, top_y)
	local bbox = bbox_from_pieces (pieces)
	local dist = top_y - base_y + 1 - bbox_height (bbox)
	local target = base_y

	if dist > 1 then
		target = target + rng:next_within (dist)
	end
	translate_vertically (pieces, target - bbox[2])
end

local function nether_fortress_create_pieces (rng, x, z, max_pieces)

	-- print ("Fortress @ " .. x .. "," .. z)

	pieces = {}
	child_queue = {}
	count_placed = {}
	previous_piece_type = nil

	for _, piece in ipairs (ALL_BRIDGE_PIECES) do
		count_placed[piece.piece_type] = 0
	end
	for _, piece in ipairs (ALL_CORRIDOR_PIECES) do
		count_placed[piece.piece_type] = 0
	end

	local start = insert_start_piece (pieces, rng, x, z)
	-- print ("Fortress initial orientation " .. start.dir)
	-- print (string.format (" initial bbox: (%d,%d,%d) - (%d,%d,%d)",
	-- 		      unpack (start.bbox)))
	start:insert_children (start, pieces, rng, x, z)
	while #child_queue >= 1 and #pieces < max_pieces do
		local idx = 1 + rng:next_within (#child_queue)
		local child = child_queue[idx]
		for i = idx, #child_queue do
			child_queue[i] = child_queue[i + 1]
		end

		if child.insert_children then
			child:insert_children (start, pieces, rng)
		end
	end
	count_placed = nil
	child_queue = nil
	fortress_shift_into (rng, pieces, 48, 70)
	return pieces
end


return {
	create_pieces = nether_fortress_create_pieces,
}
