-- Stronghold (spec 6.2): pieces from stronghold_pieces.lua (Mineclonia), at
-- most MAX_PIECES, buried with its top one node under the origin (and at most
-- at Y_MAX); every room is a part whose inhabitants are stone monsters. The
-- portal room's floor centre is kept as the target for eyes of ender.
local S = cb_structures.S
local A = cb_structures.piecegen

local door_top = core.registered_nodes["doors:hidden"] and "doors:hidden" or "air"
cb_structures.stronghold_nodes = {
	stone_bricks = "default:stonebrick",
	cracked = cb_core.equiv("cracked_stone_bricks"),
	mossy = cb_core.equiv("mossy_stone_bricks"),
	door_wood = door_top ~= "air" and A.first("doors:door_wood_a", "air") or "air",
	door_steel = door_top ~= "air" and A.first("doors:door_steel_a", "air") or "air",
	door_top = door_top,
	bars = A.first("xpanes:bar_flat", "air"),
	bars_junction = A.first("xpanes:bar", "air"),
	slab_stone = A.first("stairs:slab_stone", "default:stone"),
	slab_stone_brick = A.first("stairs:slab_stonebrick", "default:stonebrick"),
	stair_cobble = A.first("stairs:stair_cobble", "default:cobble"),
	stair_stone_brick = A.first("stairs:stair_stonebrick", "default:stonebrick"),
	cobweb = A.first("mobs:cobweb", "air"),
	bookshelf = "default:bookshelf",
	fence = A.first("default:fence_wood", "air"),
	frame = "cb_blocks:end_portal_frame",
	frame_eye = "cb_blocks:end_portal_frame_eye",
}
local N = cb_structures.stronghold_nodes
local gen = dofile(core.get_modpath("cb_structures") .. "/stronghold_pieces.lua")

local St = {
	MAX_PIECES = tonumber(cb_core.setting("cubeborn.stronghold_pieces", "50")) or 50,
	Y_MAX = -20,
	Y_MIN = (cb_dimensions.MAX_Y or -1500) + 1,
}
cb_structures.stronghold = St

function St.layout(origin, seed)
	local pieces = gen.create_pieces(A.rng(seed), St.MAX_PIECES)
	local top = -math.huge
	for _, piece in ipairs(pieces) do
		top = math.max(top, piece.bbox[5])
	end
	-- Local coordinates: world = (o.x + x, o.y + y, o.z - z).
	local o = vector.new(origin.x, math.min(origin.y - 1, St.Y_MAX) - top, origin.z)
	local out, lo, hi, target = {}, nil, nil, nil
	for i, piece in ipairs(pieces) do
		local bb = piece.bbox
		local a = vector.new(o.x + bb[1], o.y + bb[2], o.z - bb[6])
		local b = vector.new(o.x + bb[4], o.y + bb[5], o.z - bb[3])
		out[#out + 1] = { minp = a, maxp = b, part = piece.type ~= nil, build = function(ctx)
			A.begin(ctx, o)
			piece:place(A.level, nil, A.rng(seed + i))
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
		if piece.type == "portal_room" then
			target = vector.new(math.floor((a.x + b.x) / 2), a.y + 1, math.floor((a.z + b.z) / 2))
		end
	end
	return { minp = lo, maxp = hi, pieces = out, target = target, }
end

local exclude = {
	["default:lava_source"] = true, ["default:lava_flowing"] = true, ["default:water_source"] = true,
	["default:water_flowing"] = true, ["default:chest"] = true, ["default:chest_open"] = true,
	[N.frame] = true, [N.frame_eye] = true, [N.cobweb] = true, ["doors:hidden"] = true,
	["default:torch"] = true, ["default:torch_wall"] = true,
}
for _, kind in ipairs({ "wood", "steel", }) do
	for _, s in ipairs({ "a", "b", "c", "d", }) do
		exclude["doors:door_" .. kind .. "_" .. s] = true
	end
end
exclude.air = nil

cb_structures.register("stronghold", {
	description = S("Stronghold"),
	dims = { "overworld", },
	y_min = St.Y_MIN,
	y_max = St.Y_MAX,
	layout = St.layout,
	inhabitants = { mobs = { { "mobs_monster:stone_monster", 1, }, { "cb_mobs_overworld:silverfish", 2, }, }, volume = 600,
		max = 2, },
	sample_exclude = exclude,
})
