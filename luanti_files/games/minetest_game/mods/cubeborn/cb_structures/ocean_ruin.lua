-- Ocean ruins (spec cycle 7): Mineclonia's levelgen templates and numbers.
-- Cold ones (stone bricks, weathered: 50 % mossy, else 70 % cracked) in cool
-- seas, warm ones (sandstone) where the biome's heat is 50 or more. 30 % are
-- big; a big one brings, nine times in ten, 4-7 small ruins in the 16-node
-- cells around it, each on its own floor. Sand and gravel fall to the
-- ground, the insides are full of water, drowned live in big ruins. Placed
-- only by admins.
local S = cb_structures.S
local T = cb_structures.templates
local A = cb_structures.piecegen
local SW = cb_structures.shipwreck
local OR = { BIG = 30, CLUSTER = 90, }
cb_structures.ocean_ruin = OR

local SAND, GRAVEL = "default:sand", "default:gravel"
local BRICKS, CHISELED = "default:stonebrick", "default:stone_block"
local MOSSY = cb_core.equiv("mossy_stone_bricks")
local CRACKED = A.first("cb_blocks:cracked_stone_bricks", BRICKS)

T.MAP["mcl_core:stonebrick"] = BRICKS
T.MAP["mcl_core:stonebrickcarved"] = CHISELED
T.MAP["mcl_core:stonebrickmossy"] = MOSSY
T.MAP["mcl_core:stone"] = "default:stone"
T.MAP["mcl_core:cobble"] = "default:cobble"
T.MAP["mcl_core:mossycobble"] = "default:mossycobble"
T.MAP["mcl_core:sand"] = SAND
T.MAP["mcl_core:gravel"] = GRAVEL
T.MAP["mcl_core:sandstone"] = "default:sandstone"
T.MAP["mcl_core:sandstonecarved"] = "default:sandstonebrick"
T.MAP["mcl_core:sandstonesmooth"] = "default:sandstone_block"
T.MAP["mcl_core:granite_smooth"] = "default:desert_stone_block"
T.MAP["mcl_core:andesite_smooth"] = "default:stone_block"
T.MAP["mcl_nether:magma"] = A.first("cb_blocks:magma", "default:obsidian")
T.MAP["mcl_ocean:sea_lantern"] = A.first("cb_blocks:sea_lantern", "default:meselamp")
T.MAP["mcl_ocean:prismarine"] = A.first("cb_blocks:prismarine", "default:stone")
T.MAP["mcl_trees:wood_jungle"] = "default:junglewood"

local DIR = core.get_modpath("cb_structures") .. "/templates/ocean_ruins_"
local COUNT = { cold = { big = 3, small = 5, }, warm = { big = 3, small = 3, }, }
OR.TPLS = {}
for temp, sizes in pairs(COUNT) do
	OR.TPLS[temp] = {}
	for size, n in pairs(sizes) do
		OR.TPLS[temp][size] = {}
		for i = 1, n do
			OR.TPLS[temp][size][i] = T.load(DIR .. size .. "_" .. temp .. "_" .. i .. ".dat")
		end
	end
end

-- The first draws of a ruin's rng: big or not, and how many small ruins.
local function shape(rng)
	local big = rng:next(1, 100) <= OR.BIG
	local cluster = big and rng:next(1, 100) <= OR.CLUSTER and 4 + rng:next(0, 3) or 0
	return { big = big, cluster = cluster, }
end

function OR.shape(seed)
	return shape(PcgRandom(seed))
end

-- Mineclonia's randomize_cluster_poses: eight spots in the cells around the
-- big ruin's corner (cx, cz), shuffled in pairs.
local function cluster_spots(cx, cz, rng)
	local p = {
		{ rng:next(1, 7) - 16 + cx, rng:next(1, 7) - 16 + cz, },
		{ rng:next(1, 7) - 16 + cx, rng:next(1, 7) + cz, },
		{ rng:next(1, 7) - 16 + cx, rng:next(4, 7) - 16 + cz, },
		{ rng:next(1, 7) + cx, rng:next(1, 7) + 16 + cz, },
		{ rng:next(1, 7) + cx, rng:next(4, 5) - 16 + cz, },
		{ rng:next(1, 7) + cx + 16, rng:next(3, 7) + 16 + cz, },
		{ rng:next(1, 7) + cx + 16, rng:next(1, 7) + cz, },
		{ rng:next(1, 7) + cx + 16, rng:next(4, 7) + cz - 16, },
	}
	for i = #p, 2, -1 do
		local j = rng:next(1, i)
		p[i], p[j] = p[j], p[i]
	end
	return p
end

local function ruin(temp, size, rng, x, z, centred)
	local list = OR.TPLS[temp][size]
	local t, k = rng:next(1, #list), rng:next(0, 3)
	local bb = T.bbox(list[t], 0, 0, 0, k)
	local w, d = bb[4] - bb[1] + 1, bb[6] - bb[3] + 1
	if centred then
		x, z = x - math.floor(w / 2), z - math.floor(d / 2)
	end
	-- the water must cover the whole ruin
	if SW.depth(x, z, w, d) < list[t].h then
		return nil, list[t].h
	end
	local f = SW.floor_at(x + math.floor(w / 2), 1, z + math.floor(d / 2))
	return { size = size, t = t, k = k, x = x, y = f, z = z, }
end

function OR.plan(origin, seed, variant)
	local rng = PcgRandom(seed)
	local sh = shape(rng)
	local first, need = ruin(variant, sh.big and "big" or "small", rng, origin.x, origin.z, true)
	if not first then
		return nil, S("An ocean ruin needs water at least @1 deep.", need)
	end
	local ruins = { first, }
	if sh.cluster > 0 then
		for i, spot in ipairs(cluster_spots(first.x, first.z, rng)) do
			if i > sh.cluster then
				break
			end
			ruins[#ruins + 1] = ruin(variant, "small", rng, spot[1], spot[2], false)
		end
	end
	return { temp = variant, ruins = ruins, }
end

-- The ruin's box reaches SINK below its floor row: sand and gravel over a
-- lower floor fall that far.
OR.SINK = 8
local function box(r, temp)
	local tpl = OR.TPLS[temp][r.size][r.t]
	local bb = T.bbox(tpl, 0, 0, 0, r.k)
	local a = vector.new(r.x, r.y, r.z)
	local b = vector.new(r.x + bb[4] - bb[1], r.y + tpl.h - 1, r.z + bb[6] - bb[3])
	return tpl, vector.offset(a, 0, -OR.SINK, 0), b, vector.new(a.x - bb[1], a.y, b.z + bb[3])
end

local AR = rawget(_G, "cb_archaeology")
local FALLS = { [SAND] = true, [GRAVEL] = true, }
if AR then
	FALLS[AR.SAND], FALLS[AR.GRAVEL] = true, true
end
-- Up to SUSPICIOUS template gravel (cold) or sand (warm) nodes of a ruin
-- become suspicious (Mineclonia's archaeology processor).
OR.SUSPICIOUS = 5

-- Sand and gravel over water or air fall to the first walkable node; the
-- positions in `track` (hash -> true) follow their node.
local function settle(ctx, a, b, track)
	local hash = core.hash_node_position
	for y = a.y + 1, b.y do
		for x = a.x, b.x do
			for z = a.z, b.z do
				local p = vector.new(x, y, z)
				local n = ctx.get(p)
				if FALLS[n] then
					local q = p
					while true do
						local below = vector.offset(q, 0, -1, 0)
						local def = core.registered_nodes[ctx.get(below)]
						if not def or def.walkable or below.y < a.y then
							break
						end
						q = below
					end
					if q.y ~= p.y then
						ctx.set(p, p.y <= 1 and "default:water_source" or "air")
						ctx.set(q, n)
						if track[hash(p)] then
							track[hash(p)], track[hash(q)] = nil, true
						end
					end
				end
			end
		end
	end
end

function OR.layout(origin, seed, plan)
	local pieces, lo, hi = {}, nil, nil
	for i, r in ipairs(plan.ruins) do
		local tpl, a, b, anchor = box(r, plan.temp)
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or a
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or b
		local loot = r.size == "big" and "underwater_ruin_big" or "underwater_ruin_small"
		pieces[i] = { minp = a, maxp = b, part = true, kind = r.size, build = function(ctx)
			local rng = PcgRandom(seed + i)
			local target = plan.temp == "cold" and GRAVEL or SAND
			local found = {}
			T.place(ctx, tpl, anchor, 0, 0, 0, r.k, {
				loot = function(what)
					return what == "mcl_levelgen:ocean_ruins" and loot or nil
				end,
				process = function(name, pos)
					if plan.temp == "cold" and (name == BRICKS or name == CHISELED) then
						if rng:next(1, 100) <= 50 then
							name = MOSSY
						elseif rng:next(1, 100) <= 70 then
							name = CRACKED
						end
					end
					if name == target then
						found[#found + 1] = vector.copy(pos)
					end
					return SW.flood(name, pos)
				end,
			})
			for k = #found, 2, -1 do
				local j = rng:next(1, k)
				found[k], found[j] = found[j], found[k]
			end
			local track, kind = {}, plan.temp == "cold" and "gravel" or "sand"
			for k = 1, math.min(OR.SUSPICIOUS, #found) do
				if ctx.get(found[k]) == target then
					cb_structures.suspicious(ctx, found[k], kind, nil)
					track[core.hash_node_position(found[k])] = true
				end
			end
			settle(ctx, a, b, track)
			for h in pairs(track) do
				cb_structures.suspicious(ctx, core.get_position_from_hash(h), kind, "ocean_ruins_" .. plan.temp,
					rng:next())
			end
		end, }
	end
	return { minp = lo, maxp = hi, pieces = pieces, }
end

cb_structures.register("ocean_ruin", {
	description = S("Ocean Ruin"),
	dims = { "overworld", },
	water = true,
	variants = { "cold", "warm", },
	pick_variant = function(origin)
		local data = core.get_biome_data(origin)
		return data and data.heat >= 50 and "warm" or "cold"
	end,
	prepare = { radius = 48, below = 48, above = 8, },
	plan = OR.plan,
	layout = OR.layout,
	inhabitants = { kinds = {
		big = { mobs = { { "cb_mobs_overworld:drowned", 1, }, }, volume = 300, max = 3, },
	}, },
})
