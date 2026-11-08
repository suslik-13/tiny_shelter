-- Trail ruins (plan 14d): Mineclonia's templates and pools
-- (mcl_levelgen/trail_ruins.lua, GPLv3) assembled by cb_structures.jigsaw.
-- Buried like Minecraft's: the start tower stands 15 below the surface and
-- template air is not written, so the rooms stay full of the ground around
-- them. Processors as Mineclonia's: gravel weathers to dirt, mud bricks to
-- packed mud, and per piece a seeded pick of its gravel becomes suspicious
-- gravel (houses and decor 6 common + 3 rare, roads and the tower top 2
-- common). Nobody lives there; no chests.
local S = cb_structures.S
local T, J = cb_structures.templates, cb_structures.jigsaw
local DIR = core.get_modpath("cb_structures") .. "/templates/"
local TR = { RADIUS = 80, MAX_DEPTH = 7, MAX_PIECES = 64, DEPTH = 15, }
cb_structures.trail_ruins = TR

local M = T.MAP
for mcl, bc in pairs({ silver = "grey", purple = "violet", orange = "orange", brown = "brown", }) do
	M["mcl_colorblocks:hardened_clay_" .. mcl] = "bakedclay:" .. bc
	M["mcl_colorblocks:glazed_terracotta_" .. mcl] = "bakedclay:terracotta_" .. bc
end
M["mcl_mud:mud_bricks"] = "default:desert_stonebrick"
M["mcl_stairs:slab_mud_brick"] = "stairs:slab_desert_stonebrick"
M["mcl_stairs:slab_mud_brick_double"] = "default:desert_stonebrick"
M["mcl_mud:packed_mud"] = "bakedclay:brown"
M["mcl_core:coarse_dirt"] = "default:dirt"
M["mcl_core:brick_block"] = "default:brick"
M["mcl_sus_nodes:gravel"] = "default:gravel"
M["mcl_panes:bar"] = M["mcl_panes:bar"] or cb_structures.piecegen.first("xpanes:bar", "xpanes:bar_flat", "default:fence_wood")

local GRAVEL, MUD, PACKED = "default:gravel", "default:desert_stonebrick", "bakedclay:brown"

-- Template name -> loaded template, and back; kind of archaeology per pool.
local cache, names = {}, {}
TR.TEMPLATES, TR.NAMES = cache, names
local P = "mcl_levelgen:trail_ruins_"
-- { common, rare, weathering }
local HOUSES, ROADS, TOP = { 6, 3, true, }, { 2, 0, true, }, { 2, 0, false, }
local KIND = {}
local function pool(id, kind, list)
	local el = {}
	for _, n in ipairs(list) do
		local name = "trail_ruins_" .. n
		if not cache[name] then
			cache[name] = T.load(DIR .. name .. ".dat")
			names[cache[name]] = name
			KIND[cache[name]] = kind
		end
		el[#el + 1] = { tpl = cache[name], weight = 1, }
	end
	J.register_pool(P .. id, el)
end
pool("tower", HOUSES, { "tower_1", })
pool("tower_tower_top", TOP, { "tower_top_1", })
pool("tower_additions", HOUSES, { "tower_hall_1", "tower_large_hall_1", "tower_one_room_1", })
pool("buildings", HOUSES, { "buildings_group_hall_1", "buildings_large_room_1", "buildings_one_room_1", })
pool("buildings_grouped", HOUSES, {})
pool("roads", ROADS, { "roads_long_road_end", "roads_road_spacer_1", "roads_road_section_1", "roads_road_section_2",
	"roads_road_section_3", })
pool("decor", HOUSES, { "decor_decor_1", })

local function gravel_count(tpl)
	local n = 0
	for _, node in pairs(tpl.nodes) do
		n = n + ((node and node[1] == GRAVEL) and 1 or 0)
	end
	return n
end

-- Which gravel nodes (by their order in the template) turn suspicious, and
-- with which table.
function TR.picks(tpl, rng)
	local kind = KIND[tpl] or ROADS
	local n = gravel_count(tpl)
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	for i = n, 2, -1 do
		local j = rng:next(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local picks = {}
	for i = 1, math.min(kind[1] + kind[2], n) do
		picks[order[i]] = i <= kind[1] and "trail_ruins_common" or "trail_ruins_rare"
	end
	return picks, kind[3]
end

local function processor(ctx, tpl, seed)
	local rng = PcgRandom(seed)
	local picks, weather = TR.picks(tpl, rng)
	local nth = 0
	return function(name, pos)
		if name == GRAVEL then
			nth = nth + 1
			local tbl = picks[nth]
			if tbl then
				local AR = rawget(_G, "cb_archaeology")
				ctx.after(function()
					if AR and core.get_node(pos).name == AR.GRAVEL then
						AR.set_find(pos, tbl, seed + nth)
					end
				end)
				return AR and AR.GRAVEL or GRAVEL
			end
			if weather and rng:next(1, 100) <= 28 then
				return "default:dirt"
			end
		elseif name == MUD and weather and rng:next(1, 10) == 1 then
			return PACKED
		end
		return name
	end
end

function TR.layout(origin, seed)
	local R = TR.RADIUS
	local bounds = { -R, -40, -R, R, 40, R, }
	local start = cache.trail_ruins_tower_1
	local pieces = J.assemble(P .. "tower", PcgRandom(seed), -math.floor(start.w / 2), 0, -math.floor(start.l / 2),
		{ max_depth = TR.MAX_DEPTH, max_pieces = TR.MAX_PIECES, bounds = bounds, })
	local anchor = vector.new(origin.x, origin.y - TR.DEPTH, origin.z)
	local out, lo, hi = {}, nil, nil
	for i, p in ipairs(pieces) do
		local a = vector.new(anchor.x + p.bbox[1], anchor.y + p.bbox[2], anchor.z - p.bbox[6])
		local b = vector.new(anchor.x + p.bbox[4], anchor.y + p.bbox[5], anchor.z - p.bbox[3])
		out[#out + 1] = { minp = a, maxp = b, part = true, kind = "ruin", build = function(ctx)
			T.place(ctx, p.tpl, anchor, p.x, p.y, p.z, p.k,
				{ skip_air = true, process = processor(ctx, p.tpl, (seed + i * 7919) % 2147483647), })
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

cb_structures.register("trail_ruins", {
	description = S("Trail Ruins"),
	dims = { "overworld", },
	biome_words = { "taiga", "coniferous", "rainforest", "jungle", "birch", "pine", },
	prepare = { radius = 80, below = 40, above = 8, },
	layout = TR.layout,
})
