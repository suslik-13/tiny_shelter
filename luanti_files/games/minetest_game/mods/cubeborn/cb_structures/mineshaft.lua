-- Abandoned mineshaft (spec cycle 2, 4.1): Mineclonia's pieces (parlor,
-- corridors, crossings, stairs), the parlor floor at the given height, at
-- most MAX_PIECES pieces, only underground (not above -20). Minecart chests
-- become loot chests on the corridor floor; spider corridors get a cave
-- spider spawner and cobwebs. No inhabitants: spiders come from spawners.
local S = cb_structures.S
local A = cb_structures.piecegen

cb_structures.mineshaft_nodes = {
	planks = "default:wood", wood = "default:tree", fence = "default:fence_wood", chain = "default:fence_wood",
	cobweb = cb_core.equiv("cobweb"), rail = A.first("carts:rail", "air"),
}
local gen = dofile(core.get_modpath("cb_structures") .. "/mineshaft_pieces.lua")

local MS = { MAX_PIECES = tonumber(cb_core.setting("cubeborn.mineshaft_pieces", "60")) or 60, Y_MAX = -20, }
cb_structures.mineshaft = MS

MS.HANDLERS = {
	["mcl_levelgen:minecart_chest_constructor"] = function(x, y, z)
		A.set_block(x, y, z, "default:chest", 0)
		A.set_loot_table(x, y, z, nil, "abandoned_mineshaft")
	end,
	["mcl_levelgen:mob_spawner_constructor"] = function(x, y, z)
		A.construct(x, y, z)
	end,
}

-- The parlor's floor (Mineclonia's local y 50) at origin.y.
function MS.layout(origin, seed)
	local rng = A.rng(seed)
	A.max_pieces = MS.MAX_PIECES
	local pieces = {}
	local parlor = gen.create_parlor(0, rng, 0, 0, false)
	table.insert(pieces, parlor)
	gen.insert_parlor_children(rng, pieces, parlor)
	A.max_pieces = math.huge
	local dy = -parlor.bbox[2]
	A.translate_vertically(pieces, dy)
	for _, e in ipairs(parlor.entrances) do
		e[2], e[5] = e[2] + dy, e[5] + dy
	end
	local out, lo, hi = {}, nil, nil
	local BIG = 1000000
	for i, piece in ipairs(pieces) do
		local bb = piece.bbox
		-- one below: corridors patch their floor and lay rails on it
		local a = vector.new(origin.x + bb[1], origin.y + bb[2] - 1, origin.z - bb[6])
		local b = vector.new(origin.x + bb[4], origin.y + bb[5], origin.z - bb[3])
		out[#out + 1] = { minp = a, maxp = b, spiders = piece.place_spiders, build = function(ctx)
			A.begin(ctx, origin)
			A.handlers = MS.HANDLERS
			piece:place(A.level, nil, A.rng(seed + i), -BIG, -BIG, BIG, BIG)
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

cb_structures.register("mineshaft", {
	description = S("Abandoned Mineshaft"),
	dims = { "overworld", },
	underground = true,
	y_max = MS.Y_MAX,
	layout = MS.layout,
})
