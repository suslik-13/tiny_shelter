-- Desert well (spec cycle 9, 4.2): Mineclonia's desert_well_place. A cross
-- of water on a sandstone foundation, a rim, four pillars and a slab dome;
-- two suspicious sands beside the well's sand floor. Placed only by admins.
local S = cb_structures.S
local DW = {}
cb_structures.desert_well = DW

local SANDSTONE, SAND = "default:sandstone", "default:sand"
local SLAB = core.registered_nodes["stairs:slab_sandstone"] and "stairs:slab_sandstone" or SANDSTONE
local SIDES = { { 1, 0, }, { -1, 0, }, { 0, 1, }, { 0, -1, }, }

function DW.plan(origin, seed)
	local y, x1, z1 = cb_structures.surface.site(origin, 5, 5, 6, { max_drop = 3, below = 3, radius = 8, })
	if not y then
		return nil, x1
	end
	return { x = x1 + 2, y = y - 1, z = z1 + 2, }
end

-- (x, y, z): the well's centre at ground level (the water's level).
function DW.layout(origin, seed, plan)
	local c = vector.new(plan.x, plan.y, plan.z)
	local a, b = vector.offset(c, -2, -2, -2), vector.offset(c, 2, 4, 2)
	return { minp = a, maxp = b, pieces = { { minp = a, maxp = b, build = function(ctx)
		local rng = PcgRandom(seed)
		local function at(dx, dy, dz, name)
			ctx.set(vector.offset(c, dx, dy, dz), name)
		end
		ctx.fill(a, vector.offset(c, 2, 0, 2), SANDSTONE)
		ctx.fill(vector.offset(c, -2, 1, -2), b, "air")
		for dx = -1, 1 do
			for dz = -1, 1 do
				if dx == 0 or dz == 0 then
					at(dx, -1, dz, SAND)
					at(dx, 0, dz, "default:water_source")
				end
			end
		end
		for dx = -2, 2 do
			for dz = -2, 2 do
				if math.abs(dx) == 2 or math.abs(dz) == 2 then
					at(dx, 1, dz, (dx == 0 or dz == 0) and SLAB or SANDSTONE)
				end
			end
		end
		for dx = -1, 1 do
			for dz = -1, 1 do
				at(dx, 4, dz, (dx == 0 and dz == 0) and SANDSTONE or SLAB)
			end
		end
		for dy = 1, 3 do
			for _, d in ipairs({ { -1, -1, }, { -1, 1, }, { 1, -1, }, { 1, 1, }, }) do
				at(d[1], dy, d[2], SANDSTONE)
			end
		end
		local d1, d2 = SIDES[rng:next(1, 4)], SIDES[rng:next(1, 4)]
		cb_structures.suspicious(ctx, vector.offset(c, d1[1], -1, d1[2]), "sand", "desert_well", rng:next())
		cb_structures.suspicious(ctx, vector.offset(c, d2[1], -2, d2[2]), "sand", "desert_well", rng:next())
	end, }, }, }
end

cb_structures.register("desert_well", {
	description = S("Desert Well"),
	dims = { "overworld", },
	biome_words = { "desert", },
	prepare = { radius = 8, below = 4, above = 6, },
	plan = DW.plan,
	layout = DW.layout,
})
