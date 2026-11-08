-- Adapter for structure piece code ported from Mineclonia's mcl_levelgen
-- (GPLv3): random numbers, rotated boxes and writing through a build ctx.
-- Pieces are generated in Mineclonia's local coordinates; z is mirrored when
-- written, as Mineclonia's level coordinates are to Luanti's.
local A = {}
cb_structures.piecegen = A

local floor = math.floor

local Rng = {}
Rng.__index = Rng

function A.rng(seed)
	return setmetatable({ p = PcgRandom(seed), }, Rng)
end

function Rng:next_within(n)
	return self.p:next(0, n - 1)
end

function Rng:next_integer()
	return self.p:next()
end

function Rng:next_boolean()
	return self.p:next(0, 1) == 1
end

function Rng:next_float()
	return self.p:next(0, 16777215) / 16777216
end

function Rng:next_double()
	return self.p:next(0, 16777215) / 16777216
end

-- A fresh sequence seeded by a position.
function Rng:reseed_positional(x, y, z)
	self.p = PcgRandom(x * 73856093 + y * 19349663 + z * 83492791)
end

local DIRS = { "north", "east", "south", "west", }

function A.random_orientation(rng)
	return DIRS[1 + rng:next_within(4)]
end

function A.make_rotated_bbox(x, y, z, dir, w, h, l)
	if dir == "north" or dir == "south" then
		return { x, y, z, x + w - 1, y + h - 1, z + l - 1, }
	end
	return { x, y, z, x + l - 1, y + h - 1, z + w - 1, }
end

function A.rotated_block_box(x, y, z, dx, dy, dz, w, h, l, dir)
	if dir == "south" then
		return { x + dx, y + dy, z + dz, x + w - 1 + dx, y + h - 1 + dy, z + l - 1 + dz, }
	elseif dir == "north" then
		return { x + dx, y + dy, z - l + 1 + dz, x + w - 1 + dx, y + h - 1 + dy, z + dz, }
	elseif dir == "west" then
		return { x - l + 1 + dz, y + dy, z + dx, x + dz, y + h - 1 + dy, z + w - 1 + dx, }
	end
	return { x + dz, y + dy, z + dx, x + l - 1 + dz, y + h - 1 + dy, z + w - 1 + dx, }
end

function A.reorientate_coords(piece, x, y, z)
	local dir, b = piece.dir, piece.bbox
	if dir == "north" then
		return b[1] + x, b[2] + y, b[6] - z
	elseif dir == "south" then
		return b[1] + x, b[2] + y, b[3] + z
	elseif dir == "west" then
		return b[4] - z, b[2] + y, b[3] + x
	end
	return b[1] + z, b[2] + y, b[3] + x
end

local function intersect(a, b)
	return a[1] <= b[4] and a[4] >= b[1] and a[2] <= b[5] and a[5] >= b[2] and a[3] <= b[6] and a[6] >= b[3]
end

-- A.bounds = {x1, z1, x2, z2} (local) keeps pieces inside a pocket.
function A.any_collisions(pieces, bbox)
	local bd = A.bounds
	if bd and (bbox[1] < bd[1] or bbox[3] < bd[2] or bbox[4] > bd[3] or bbox[6] > bd[4]) then
		return true
	end
	for _, piece in ipairs(pieces) do
		if intersect(piece.bbox, bbox) then
			return true
		end
	end
	return false
end

function A.AABB_intersect_p(a, b)
	return intersect(a, b)
end

function A.first_collision(pieces, bbox)
	for _, piece in ipairs(pieces) do
		if intersect(piece.bbox, bbox) then
			return piece
		end
	end
	return nil
end

function A.bbox_width_x(b)
	return b[4] - b[1] + 1
end

function A.bbox_width_z(b)
	return b[6] - b[3] + 1
end

-- The first registered node name, else the last argument (a safe fallback).
function A.first(...)
	local names = { ... }
	for _, name in ipairs(names) do
		if core.registered_nodes[name] then
			return name
		end
	end
	return names[#names]
end

function A.bbox_from_pieces(pieces)
	local b = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge, }
	for _, piece in ipairs(pieces) do
		local p = piece.bbox
		for i = 1, 3 do
			b[i] = math.min(b[i], p[i])
			b[i + 3] = math.max(b[i + 3], p[i + 3])
		end
	end
	return b
end

function A.bbox_height(b)
	return b[5] - b[2] + 1
end

function A.translate_vertically(pieces, dy)
	for _, piece in ipairs(pieces) do
		piece.bbox[2] = piece.bbox[2] + dy
		piece.bbox[5] = piece.bbox[5] + dy
	end
end

function A.ipos3(x1, y1, z1, x2, y2, z2)
	local x, y, z = x1 - 1, y1, z1
	return function()
		x = x + 1
		if x > x2 then
			x, y = x1, y + 1
			if y > y2 then
				y, z = y1, z + 1
				if z > z2 then
					return nil
				end
			end
		end
		return x, y, z
	end
end

-- Writing.
local ctx, origin, last_param2 = nil, nil, {}
A.level = { preset = { min_y = 0, }, }

function A.begin(c, o)
	ctx, origin, last_param2 = c, o, {}
end

function A.to_world(x, y, z)
	return vector.new(origin.x + x, origin.y + y, origin.z - z)
end

-- pred (optional): writes only where pred(current node) holds.
function A.set_block(x, y, z, name, param2, pred)
	local pos = A.to_world(x, y, z)
	if pred and not pred(ctx.get(pos), 0) then
		return
	end
	ctx.set(pos, name, param2)
	if A.CONSTRUCT[name] then
		ctx.construct(pos)
	end
	last_param2[x .. "," .. y .. "," .. z] = param2
end

local WATER_AIR_LAVA = {
	air = true, ignore = true, ["default:water_source"] = true, ["default:water_flowing"] = true,
	["default:lava_source"] = true, ["default:lava_flowing"] = true,
}

function A.is_water_air_or_lava(x, y, z)
	return WATER_AIR_LAVA[ctx.get(A.to_world(x, y, z))] == true
end

function A.get_block(x, y, z)
	return ctx.get(A.to_world(x, y, z)), 0
end

function A.set_loot_table(x, y, z, _, name)
	ctx.chest(A.to_world(x, y, z), name, last_param2[x .. "," .. y .. "," .. z])
end

-- A suspicious block ("sand" or "gravel") that brushing opens with find
-- table `name`; plain sand or gravel without cb_archaeology.
function A.set_suspicious(x, y, z, kind, name, seed)
	local pos = A.to_world(x, y, z)
	cb_structures.suspicious(ctx, pos, kind, name, seed)
end

function A.construct(x, y, z)
	ctx.construct(A.to_world(x, y, z))
end

-- Level API used by the ported pieces (mineshaft, desert temple, witch hut).
-- Everything counts as underground: no heightmap, no biomes.
A.FACE_UP, A.FACE_DOWN = 1, 2
A.registered_biomes = { { groups = {}, }, }
A.placement_level_min, A.placement_level_height = -31000, 62000
A.max_pieces = math.huge
A.handlers = {}
-- Nodes whose on_construct runs after the piece is written.
A.CONSTRUCT = {}

function A.index_biome()
	return 1
end

-- A.heightmap(x, z) (set by a structure while it builds) answers instead.
function A.index_heightmap(x, z, ...)
	if A.heightmap then
		return A.heightmap(x, z, ...)
	end
	return math.huge, math.huge
end

local function sturdy(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false and (def.drawtype == nil or def.drawtype == "normal")
end

function A.opaque_p(name)
	return sturdy(name)
end

function A.is_walkable(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false
end

function A.get_sturdy_faces(x, y, z)
	return sturdy((A.get_block(x, y, z))) and 63 or 0
end

local SIDES = { { 1, 0, 0, }, { -1, 0, 0, }, { 0, 1, 0, }, { 0, -1, 0, }, { 0, 0, 1, }, { 0, 0, -1, }, }

function A.count_sturdy_neighbors(x, y, z)
	local n = 0
	for _, d in ipairs(SIDES) do
		n = n + (sturdy((A.get_block(x + d[1], y + d[2], z + d[3]))) and 1 or 0)
	end
	return n
end

-- Writes only where pred(current node) holds; outside the piece box nothing.
function A.set_block_checked(x, y, z, name, param2, pred)
	local cur = A.get_block(x, y, z)
	if cur ~= "ignore" and pred(cur, 0) then
		A.set_block(x, y, z, name, param2)
	end
end

function A.notify_generated(kind, x, y, z, data)
	local h = A.handlers[kind]
	if h then
		h(x, y, z, data)
	end
end

function A.bbox_center(b)
	return floor((b[1] + b[4]) / 2), floor((b[2] + b[5]) / 2), floor((b[3] + b[6]) / 2)
end

function A.fisher_yates(t, rng)
	for i = #t, 2, -1 do
		local j = rng:next_within(i) + 1
		t[i], t[j] = t[j], t[i]
	end
end

-- An entity once the piece is on the map.
function A.create_entity(x, y, z, name)
	local pos = A.to_world(x, y, z)
	ctx.after(function()
		if core.registered_entities[name] then
			core.add_entity(pos, name)
		end
	end)
end


-- More of the level API (ocean monument).
A.bit = rawget(_G, "bit")
if not A.bit then
	-- plain Lua: the few operations the pieces need, on non-negative numbers
	local function op(a, b, f)
		local r, m = 0, 1
		while a > 0 or b > 0 do
			if f(a % 2, b % 2) then
				r = r + m
			end
			a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
		end
		return r
	end
	A.bit = {
		band = function(a, b) return op(a, b, function(x, y) return x == 1 and y == 1 end) end,
		bor = function(a, b) return op(a, b, function(x, y) return x == 1 or y == 1 end) end,
		bnot = function(a) return -1 - a end,
		lshift = function(a, n) return a * 2 ^ n end,
		rshift = function(a, n) return math.floor(a / 2 ^ n) end,
	}
end

function A.translate_pieces(pieces, dx, dy, dz)
	for _, piece in ipairs(pieces) do
		local b = piece.bbox
		b[1], b[2], b[3], b[4], b[5], b[6] = b[1] + dx, b[2] + dy, b[3] + dz, b[4] + dx, b[5] + dy, b[6] + dz
	end
end

function A.intersect_2d_p(b, x1, z1, x2, z2)
	return b[1] <= x2 and b[4] >= x1 and b[3] <= z2 and b[6] >= z1
end

local WATER = { ["default:water_source"] = true, ["default:water_flowing"] = true,
	["default:river_water_source"] = true, ["default:river_water_flowing"] = true, }

function A.water_source_p(name)
	return name == "default:water_source" or name == "default:river_water_source"
end

function A.water_or_air_p(name)
	return name == "air" or WATER[name] == true
end
