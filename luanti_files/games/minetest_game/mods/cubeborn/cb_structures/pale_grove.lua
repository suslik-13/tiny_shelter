-- Pale grove (plan 8f-2): no new biome, so a pale garden is a patch built on
-- the ground by /cb_spawn pale_grove (or /cb_scatter): pale moss and moss
-- carpets over the soil within RADIUS, pale oaks on a loose grid, hanging moss
-- under their leaves. About one tree in ten (at least one per grove) carries
-- a natural creaking heart in its trunk, which calls a creaking at night
-- (cb_mobs_trial). Nobody else lives there.
local S = cb_structures.S
local SU = cb_structures.surface
local PG = { RADIUS = 20, STEP = 7, HEART_CHANCE = 0.1, TREE_ROOM = 14, }
cb_structures.pale_grove = PG
local MOSS, CARPET, HEART = "cb_blocks:pale_moss", "cb_blocks:pale_moss_carpet", "cb_mobs_trial:creaking_heart_dormant"

local function idx(dx, dz)
	return (dx + PG.RADIUS) * (2 * PG.RADIUS + 1) + dz + PG.RADIUS + 1
end

-- Ground heights within RADIUS and the tree spots.
function PG.plan(origin, seed)
	local R = PG.RADIUS
	local reader = SU.reader(vector.offset(origin, -R, -24, -R), vector.offset(origin, R + 1, 40, R + 1))
	local h, n = {}, 0
	for dx = -R, R do
		for dz = -R, R do
			local y = reader:surface(origin.x + dx, origin.z + dz)
			h[idx(dx, dz)] = y or false
			n = n + (y and 1 or 0)
		end
	end
	if n < (2 * R + 1) ^ 2 * 0.6 then
		return nil, S("No flat free ground here.")
	end
	local rng = PcgRandom(seed)
	local trees = {}
	for gx = -R + 3, R - 4, PG.STEP do
		for gz = -R + 3, R - 4, PG.STEP do
			local dx, dz = gx + rng:next(-2, 2), gz + rng:next(-2, 2)
			local y = h[idx(dx, dz)]
			if y and h[idx(dx + 1, dz)] == y and h[idx(dx, dz + 1)] == y and h[idx(dx + 1, dz + 1)] == y
					and dx * dx + dz * dz <= R * R and rng:next(1, 100) <= 75 then
				trees[#trees + 1] = { dx = dx, dz = dz, y = y, heart = rng:next(1, 1000) <= PG.HEART_CHANCE * 1000, }
			end
		end
	end
	if #trees == 0 then
		return nil, S("No flat free ground here.")
	end
	local any = false
	for _, t in ipairs(trees) do
		any = any or t.heart
	end
	if not any then
		trees[rng:next(1, #trees)].heart = true
	end
	return { h = h, trees = trees, }
end

function PG.layout(origin, seed, plan)
	local R = PG.RADIUS
	local lo, hi = math.huge, -math.huge
	for _, y in pairs(plan.h) do
		if y then
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
	end
	local minp = vector.new(origin.x - R, lo - 1, origin.z - R)
	local maxp = vector.new(origin.x + R + 1, hi + PG.TREE_ROOM, origin.z + R + 1)
	local piece = { minp = minp, maxp = maxp, part = true, kind = "grove", build = function(ctx)
		local rng = PcgRandom(seed + 1)
		local function rand(a, b)
			return rng:next(a, b)
		end
		for dx = -R, R do
			for dz = -R, R do
				local y = plan.h[idx(dx, dz)]
				local d = math.sqrt(dx * dx + dz * dz)
				if y and d <= R - rng:next(0, 3) then
					local g = vector.new(origin.x + dx, y, origin.z + dz)
					if core.get_item_group(ctx.get(g), "soil") > 0 and rng:next(1, 10) <= 7 then
						ctx.set(g, MOSS)
						local above = vector.offset(g, 0, 1, 0)
						if ctx.get(above) == "air" and rng:next(1, 8) == 1 then
							ctx.set(above, CARPET)
						end
					end
				end
			end
		end
		for _, t in ipairs(plan.trees) do
			local base = vector.new(origin.x + t.dx, t.y + 1, origin.z + t.dz)
			for ddx = 0, 1 do
				for ddz = 0, 1 do
					ctx.set(vector.offset(base, ddx, -1, ddz), MOSS)
				end
			end
			cb_blocks.pale_oak_tree(base, rand, ctx.set, ctx.get)
			if t.heart then
				local hp = vector.offset(base, rng:next(0, 1), rng:next(2, 4), rng:next(0, 1))
				ctx.set(hp, HEART, 0)
				ctx.construct(hp)
				ctx.after(function()
					core.get_meta(hp):set_string("natural", "1")
				end)
			end
		end
	end, }
	return { minp = minp, maxp = maxp, pieces = { piece, }, }
end

cb_structures.register("pale_grove", {
	description = S("Pale Grove"),
	dims = { "overworld", },
	biome_words = { "forest", "deciduous", "coniferous", "taiga", "grassland", },
	prepare = { radius = PG.RADIUS + 1, below = 24, above = 40, },
	plan = PG.plan,
	layout = PG.layout,
	sample_exclude = { [CARPET] = true, ["cb_blocks:pale_hanging_moss"] = true, ["cb_blocks:pale_oak_leaves"] = true, },
})
