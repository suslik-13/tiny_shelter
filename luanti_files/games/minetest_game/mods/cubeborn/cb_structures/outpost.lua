-- Pillager outpost (spec cycle 2, 5.1): a tall or short tower and 8-10
-- tents, cages and scarecrows around it (Mineclonia's offsets), each on its
-- own ground. The iron golem in a cage comes once; pillagers come back to the
-- tower, one of them a captain.
local S = cb_structures.S
local VS, VL, SU = cb_structures.village_schem, cb_structures.village, cb_structures.surface
local OP = { FEATURES = { "outpost_tent", "outpost_cage_2", "outpost_cage_1", },
	OFFSETS = { { -12, 12, }, { 12, 12, }, { 16, -12, }, }, }
cb_structures.outpost = OP
local PN = "cb_mobs_illager:pillager"

local function feature_spot(reader, name, k, x, z)
	local s = VS.get(name)
	local w, d = VS.footprint(s, k)
	local y = reader:surface(x + math.floor(w / 2), z + math.floor(d / 2))
	if not y then
		return nil
	end
	local res = cb_core.check_area_now(vector.new(x, y - 3, z), vector.new(x + w - 1, y + s.y, z + d - 1))
	return res.ok and { n = name, x = x, y = y, z = z, k = k, } or nil
end

function OP.plan(origin, seed)
	local rng = PcgRandom(seed)
	local tower = rng:next(0, 1) == 0 and "outpost_tower_short" or "outpost_tower_tall"
	local k = rng:next(0, 3)
	local s = VS.get(tower)
	local w, d = VS.footprint(s, k)
	local y, x1, z1 = SU.site(origin, w, d, s.y, { max_drop = 6, below = 6, })
	if not y then
		return nil, x1
	end
	local b = { { n = tower, x = x1, y = y, z = z1, k = k, }, }
	local reader = SU.reader(vector.offset(origin, -60, -24, -60), vector.offset(origin, 60, 40, 60))
	local used = {}
	for _ = 1, 8 + rng:next(0, 2) do
		local idx = rng:next(1, 3)
		local off = OP.OFFSETS[idx]
		local ox, oz = off[1], off[2]
		if k == 1 then
			ox, oz = oz, -ox
		elseif k == 2 then
			ox, oz = -ox, -oz
		elseif k == 3 then
			ox, oz = -oz, ox
		end
		local fx = ox < 0 and x1 + ox or x1 + w - 1 + ox
		local fz = oz < 0 and z1 + oz or z1 + d - 1 + oz
		local name = used[idx] and "outpost_scarecrow" or OP.FEATURES[rng:next(1, 3)]
		local dx, dz = used[idx] and rng:next(-6, -3) or 0, used[idx] and rng:next(-6, -3) or 0
		local f = feature_spot(reader, name, used[idx] and k or rng:next(0, 3), fx + dx, fz + dz)
		local clear = f ~= nil
		for _, o in ipairs(b) do
			local os = VS.get(o.n)
			local ow, od = VS.footprint(os, o.k)
			if f then
				local fw, fd = VS.footprint(VS.get(f.n), f.k)
				clear = clear and not (f.x <= o.x + ow and o.x <= f.x + fw and f.z <= o.z + od and o.z <= f.z + fd)
			end
		end
		if clear then
			b[#b + 1] = f
			used[idx] = true
		end
	end
	return { v = "outpost", b = b, }
end

function OP.layout(origin, seed, plan)
	local pieces, lo, hi = {}, nil, nil
	for i, b in ipairs(plan.b) do
		local s = VS.get(b.n)
		local w, d = VS.footprint(s, b.k)
		local minp = vector.new(b.x, b.y, b.z)
		local fmin, fmax = vector.offset(minp, 0, -6, 0), vector.offset(minp, w - 1, s.y + 1, d - 1)
		pieces[#pieces + 1] = { minp = fmin, maxp = fmax, build = function(ctx)
			VL.ground_piece(ctx, fmin, fmax, minp.y, "outpost")
		end, }
		pieces[#pieces + 1] = { minp = minp, maxp = vector.offset(minp, w - 1, s.y - 1, d - 1), part = i == 1,
			kind = i == 1 and "tower" or nil, build = function(ctx)
				VS.place(ctx, s, minp, b.k, "outpost", "pillager_outpost")
				if b.n == "outpost_cage_1" then
					local c = vector.offset(minp, math.floor(w / 2), 1, math.floor(d / 2))
					ctx.after(function()
						if core.registered_entities["cb_mobs_village:iron_golem"] then
							core.add_entity(c, "cb_mobs_village:iron_golem")
						end
					end)
				end
			end, }
		lo = lo and vector.new(math.min(lo.x, fmin.x), math.min(lo.y, fmin.y), math.min(lo.z, fmin.z)) or vector.copy(fmin)
		hi = hi and vector.new(math.max(hi.x, fmax.x), math.max(hi.y, fmax.y), math.max(hi.z, fmax.z)) or vector.copy(fmax)
	end
	return { minp = lo, maxp = hi, pieces = pieces, plan = plan, }
end

-- One captain per tower: a new pillager becomes one if none is around, the
-- first at once, a killed one's successor after cubeborn.rare_respawn_hours.
-- The same way one allay (kept by the pillagers) comes with a new pillager.
cb_structures.OUTPOST_ALLAY = "cb_mobs_animals:allay"
local function captain(ent, part, _, id)
	local captain_alive, allay_alive = false, false
	for _, obj in ipairs(core.get_objects_in_area(vector.subtract(part.minp, 16), vector.add(part.maxp, 16))) do
		local e = obj:get_luaentity()
		if e and e ~= ent then
			captain_alive = captain_alive or e._captain == true
			allay_alive = allay_alive or e.name == cb_structures.OUTPOST_ALLAY
		end
	end
	local R = cb_structures.respawn
	if R.rare_ready(id, part, "c", captain_alive) and cb_mobs_illager then
		cb_mobs_illager.make_captain(ent)
		R.rare_given(id, part, "c")
	end
	local pos = ent.object:get_pos()
	if pos and core.registered_entities[cb_structures.OUTPOST_ALLAY] and R.rare_ready(id, part, "a", allay_alive) then
		core.add_entity(vector.offset(pos, 0, 1.5, 0), cb_structures.OUTPOST_ALLAY)
		R.rare_given(id, part, "a")
	end
end

cb_structures.register("outpost", {
	description = S("Pillager Outpost"),
	dims = { "overworld", },
	biome_words = { "desert", "plains", "grassland", "savanna", "taiga", "snowy", "coniferous", },
	prepare = { radius = 64, below = 24, above = 48, },
	plan = OP.plan,
	layout = OP.layout,
	self_checked = true,
	inhabitants = { kinds = {
		tower = { mobs = { { PN, 1, }, }, norm = function(_, part)
			local v = (part.maxp.x - part.minp.x + 1) * (part.maxp.y - part.minp.y + 1) * (part.maxp.z - part.minp.z + 1)
			return math.max(2, math.min(6, math.floor(v / 400)))
		end, margin = 8, on_spawn = captain, },
	}, },
})
