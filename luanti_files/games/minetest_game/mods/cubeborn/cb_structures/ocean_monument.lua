-- Ocean monument (spec cycle 4, 8c): pieces from ocean_monument_pieces.lua
-- (Mineclonia). Minecraft builds it at level y 39..61 under a sea at 63;
-- here the same height under our sea (water up to y 1): the top at y 0,
-- prismarine struts down to the sea floor. Needs deep water (at least 20
-- below sea level over the whole footprint). It is written in 16x16 columns
-- (the generator runs for each, writes outside the column are dropped); the
-- rooms are parts for guardians, the two wings and the penthouse for the
-- three elder guardians (rare, like other rare inhabitants). Placed only by
-- admins (/cb_spawn, /cb_scatter).
local S = cb_structures.S
local A = cb_structures.piecegen

cb_structures.monument_nodes = {
	packed_ice = A.first("cb_blocks:packed_ice", "default:ice"),
	blue_ice = A.first("cb_blocks:blue_ice", "default:ice"),
}
local gen = dofile(core.get_modpath("cb_structures") .. "/ocean_monument_pieces.lua")

local OM = { SEA = 63, SIZE = 58, STRUT = 40, COLUMN = 16, DEPTH = 20, }
cb_structures.ocean_monument = OM
local GUARDIAN, ELDER = "cb_mobs_water:guardian", "cb_mobs_water:elder_guardian"
local WATER = { ["default:water_source"] = true, ["default:water_flowing"] = true, }

-- Level (0, 0, 0) of the pieces in the world: the monument's centre is at
-- origin.x/z; Minecraft's sea level 63 is the first air above the water, our
-- water reaches y 1, so level 63 is world y 2.
local function level_origin(origin)
	return vector.new(origin.x - OM.SIZE / 2, 2 - OM.SEA, origin.z + OM.SIZE / 2)
end

-- Deep water over the footprint: 9 columns, water from 0 down to -DEPTH.
function OM.plan(origin)
	for _, dx in ipairs({ -26, 0, 26, }) do
		for _, dz in ipairs({ -26, 0, 26, }) do
			for y = 0, -OM.DEPTH, -4 do
				if not WATER[core.get_node(vector.new(origin.x + dx, y, origin.z + dz)).name] then
					return nil, S("An ocean monument needs deep water (@1 nodes below the sea) all around.", OM.DEPTH)
				end
			end
		end
	end
	return { ok = true, }
end

-- The sea floor under level x, z, as level heights: the first solid node
-- below the monument base, read through the build context.
local function sea_floor(base)
	return function(x, z)
		for y = base - 1, base - OM.STRUT, -1 do
			local name = A.get_block(x, y, z)
			local def = core.registered_nodes[name]
			if name ~= "ignore" and def and def.walkable then
				return 0, y + 1
			end
		end
		return 0, -1000
	end
end

function OM.layout(origin, seed)
	local o = level_origin(origin)
	local meta = gen.create_base(A.rng(seed), 0, 0)
	local bb = meta.bbox
	local base = bb[2]
	local function world_box(b)
		return vector.new(o.x + b[1], o.y + b[2], o.z - b[6]), vector.new(o.x + b[4], o.y + b[5], o.z - b[3])
	end
	-- the graded clearing reaches 5 beyond the walls; struts reach the floor
	local lo = vector.new(o.x + bb[1] - 5, o.y + base - OM.STRUT, o.z - bb[6] - 5)
	local hi = vector.new(o.x + bb[4] + 5, o.y + math.max(bb[5], OM.SEA + 1), o.z - bb[3] + 5)
	local out = {}
	local function build(ctx)
		A.begin(ctx, o)
		A.level.preset.sea_level = OM.SEA
		A.heightmap = sea_floor(base)
		A.handlers["mcl_levelgen:monument_elder_guardian"] = function(x, y, z)
			A.create_entity(x, y, z, ELDER)
		end
		meta:place(A.level, nil, A.rng(seed), -1e9, -1e9, 1e9, 1e9)
		A.heightmap = nil
	end
	for x = lo.x, hi.x, OM.COLUMN do
		for z = lo.z, hi.z, OM.COLUMN do
			out[#out + 1] = { minp = vector.new(x, lo.y, z),
				maxp = vector.new(math.min(x + OM.COLUMN - 1, hi.x), hi.y, math.min(z + OM.COLUMN - 1, hi.z)), build = build, }
		end
	end
	-- the last three pieces are the wings and the penthouse
	local n = #meta.pieces
	for i, piece in ipairs(meta.pieces) do
		local a, b = world_box(piece.bbox)
		out[#out + 1] = { minp = a, maxp = b, part = true, kind = i > n - 3 and "elder" or "room", }
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

cb_structures.register("ocean_monument", {
	description = S("Ocean Monument"),
	dims = { "overworld", },
	water = true,
	prepare = { radius = 40, below = 64, above = 4, },
	plan = OM.plan,
	layout = OM.layout,
	inhabitants = { kinds = {
		room = { mobs = { { GUARDIAN, 1, }, }, volume = 500, max = 2, },
		elder = { mobs = { { ELDER, 1, "elder", }, }, volume = 1e9, max = 1, },
	}, },
	sample_exclude = { ["default:water_source"] = true, ["default:water_flowing"] = true, ["air"] = true,
		["cb_blocks:wet_sponge"] = true, },
})
