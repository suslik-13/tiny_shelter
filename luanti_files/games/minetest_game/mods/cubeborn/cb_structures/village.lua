-- Village (spec cycle 2, 3.1): the belltower in the middle, buildings around
-- it on their own ground level, paths from doors to the centre. plan() reads
-- the map once (surface, free space per building with check_area_now);
-- layout() builds pieces from the plan only. Cost: plan reads one VoxelManip
-- of ~ 130x64x130 and checks up to 32 small boxes per building, once per
-- command; the build is the usual job, one piece per step.
local S = cb_structures.S
local VS, VP, SU = cb_structures.village_schem, cb_structures.village_palettes, cb_structures.surface
local VL = { RADIUS = 48, GAP = 3, MAX_DROP = 8, FOUNDATION = 8, CLEAR = 2, SCAN_UP = 40, SCAN_DOWN = 24,
	TRIES = 32, on_built = {}, }
cb_structures.village = VL

VL.SIZE_MIN = tonumber(cb_core.setting("cubeborn.village_size_min", "8")) or 8
VL.SIZE_MAX = tonumber(cb_core.setting("cubeborn.village_size_max", "20")) or 20
local HOUSES = { "house_1_bed", "house_2_bed", "house_3_bed", "house_4_bed", }
local FARMS = { "farm", "farm_small_1", "farm_small_2", "farm_large_1", }
local LAMPS = { "lamp_1", "lamp_2", "lamp_3", "lamp_4", "lamp_5", "lamp_6", }
local JOBS = { "blacksmith", "butcher", "cartographer", "chapel", "church", "fletcher", "leather_worker", "library",
	"mason", "mill", "toolsmith", "weaponsmith", }
local JOB_LOOT = { blacksmith = "village_armorer", butcher = "village_butcher", cartographer = "village_cartographer",
	chapel = "village_temple", church = "village_temple", fletcher = "village_fletcher",
	leather_worker = "village_tannery", mason = "village_mason", mill = "village_shepherd",
	toolsmith = "village_toolsmith", weaponsmith = "village_weaponsmith", }

function VL.loot_for(name, variant)
	return JOB_LOOT[name] or ("village_" .. variant .. "_house")
end

local function pick(list, rng)
	return list[rng:next(1, #list)]
end

-- belltower, well, a farm, two houses, then weighted extras up to n.
function VL.pick_buildings(rng)
	local n = rng:next(VL.SIZE_MIN, math.max(VL.SIZE_MIN, VL.SIZE_MAX))
	local list = { "belltower", "well", pick(FARMS, rng), pick(HOUSES, rng), pick(HOUSES, rng), }
	local jobs = table.copy(JOBS)
	while #list < n do
		local r = rng:next(1, 14)
		if r <= 6 or (r <= 10 and #jobs == 0) then
			list[#list + 1] = pick(HOUSES, rng)
		elseif r <= 10 then
			list[#list + 1] = table.remove(jobs, rng:next(1, #jobs))
		elseif r <= 12 then
			list[#list + 1] = pick(FARMS, rng)
		else
			list[#list + 1] = pick(LAMPS, rng)
		end
	end
	return list
end

local function overlaps(a, b, gap)
	return a[1] - gap <= b[3] and b[1] <= a[3] + gap and a[2] - gap <= b[4] and b[2] <= a[4] + gap
end

-- Floor for a footprint: the highest surface on a grid of samples (every 3
-- nodes and the edges); nil when one is missing (water, a build) or the drop
-- under it is above MAX_DROP.
local function axis(a, b)
	local list = {}
	for v = a, b, 3 do
		list[#list + 1] = v
	end
	if list[#list] ~= b then
		list[#list + 1] = b
	end
	return list
end

local function floor_of(reader, x1, z1, x2, z2)
	local lo, hi = math.huge, -math.huge
	for _, x in ipairs(axis(x1, x2)) do
		for _, z in ipairs(axis(z1, z2)) do
			local y = reader:surface(x, z)
			if not y then
				return nil
			end
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
	end
	if hi - lo > VL.MAX_DROP then
		return nil
	end
	return hi
end

local function try_spot(name, s, k, x1, z1, origin, reader, rects)
	local w, d = VS.footprint(s, k)
	local x2, z2 = x1 + w - 1, z1 + d - 1
	local R = VL.RADIUS
	if x1 < origin.x - R or x2 > origin.x + R or z1 < origin.z - R or z2 > origin.z + R then
		return nil
	end
	local r = { x1, z1, x2, z2, }
	for _, o in ipairs(rects) do
		if overlaps(r, o, VL.GAP) then
			return nil
		end
	end
	local y = floor_of(reader, x1, z1, x2, z2)
	if not y then
		return nil
	end
	local res = cb_core.check_area_now(vector.new(x1, y - VL.FOUNDATION, z1), vector.new(x2, y + s.y + VL.CLEAR, z2))
	if not res.ok then
		return nil
	end
	return { n = name, x = x1, y = y, z = z1, k = k, }, r
end

local function spot(i, name, origin, rng, reader, rects)
	local s = VS.get(name)
	if i == 1 then
		for _, o in ipairs({ { 0, 0, }, { 4, 0, }, { -4, 0, }, { 0, 4, }, { 0, -4, }, { 8, 8, }, { -8, -8, }, { 8, -8, },
			{ -8, 8, }, }) do
			local w, d = VS.footprint(s, 0)
			local b, r = try_spot(name, s, 0, origin.x + o[1] - math.floor(w / 2), origin.z + o[2] - math.floor(d / 2),
				origin, reader, rects)
			if b then
				return b, r
			end
		end
		return nil
	end
	local angle = rng:next(0, 359) * math.pi / 180
	for t = 0, VL.TRIES - 1 do
		local k = rng:next(0, 3)
		local w, d = VS.footprint(s, k)
		local dist = 14 + math.floor(t / 8) * 8 + math.max(w, d) / 2
		local a = angle + t * 0.7
		local cx, cz = origin.x + math.floor(dist * math.cos(a)), origin.z + math.floor(dist * math.sin(a))
		local b, r = try_spot(name, s, k, cx - math.floor(w / 2), cz - math.floor(d / 2), origin, reader, rects)
		if b then
			return b, r
		end
	end
end

-- Paths: an L from every path end to the centre (x first, then z), kept
-- only where the thin box of a leg is free.
local function paths(plan, center)
	local out = {}
	local c = plan.b[1]
	for i = 2, #plan.b do
		local b = plan.b[i]
		local s = VS.get(b.n)
		for _, e in ipairs(VS.world_marks(s, b.k, vector.new(b.x, b.y, b.z), "path_endpoint")) do
			local y1, y2 = math.min(e.y, c.y) - 6, math.max(e.y, c.y) + 6
			for _, leg in ipairs({ { e.x, e.z, center.x, e.z, }, { center.x, e.z, center.x, center.z, }, }) do
				local x1, x2 = math.min(leg[1], leg[3]), math.max(leg[1], leg[3])
				local z1, z2 = math.min(leg[2], leg[4]), math.max(leg[2], leg[4])
				if cb_core.check_area_now(vector.new(x1, y1, z1), vector.new(x2, y2, z2)).ok then
					out[#out + 1] = { x1, z1, x2, z2, y1, y2, }
				end
			end
		end
	end
	return out
end

function VL.plan(origin, seed, variant)
	local rng = PcgRandom(seed)
	local R = VL.RADIUS + 16
	local reader = SU.reader(vector.offset(origin, -R, -VL.SCAN_DOWN, -R), vector.offset(origin, R, VL.SCAN_UP, R))
	local placed, rects = {}, {}
	local houses, farm, well = 0, false, false
	for i, name in ipairs(VL.pick_buildings(rng)) do
		local b, r = spot(i, name, origin, rng, reader, rects)
		if b then
			placed[#placed + 1], rects[#rects + 1] = b, r
			houses = houses + (VS.get(name).beds > 0 and 1 or 0)
			farm = farm or name:find("^farm") ~= nil
			well = well or name == "well"
		elseif i == 1 then
			return nil, S("No flat free ground for the village centre here.")
		end
	end
	if houses < 2 or not farm or not well then
		return nil, S("Not enough flat free ground for a village here.")
	end
	local c = placed[1]
	local cs = VS.get(c.n)
	local cw, cd = VS.footprint(cs, c.k)
	local center = vector.new(c.x + math.floor(cw / 2), c.y, c.z + math.floor(cd / 2))
	local plan = { v = variant, c = center, b = placed, }
	plan.p = paths(plan, center)
	return plan
end

-- Foundation under the floor (down to ground, at most FOUNDATION) and
-- clearing of natural non-ground nodes above it (with `cut` the ground too).
local function ground_piece(ctx, minp, maxp, floor, palette, cut)
	local found = VP.get(palette, "foundation")
	for x = minp.x, maxp.x do
		for z = minp.z, maxp.z do
			for y = floor - 1, minp.y, -1 do
				local p = vector.new(x, y, z)
				local k = SU.kind(ctx.get(p))
				if k == "ground" or k == nil then
					break
				end
				ctx.set(p, found)
			end
			for y = floor, maxp.y do
				local p = vector.new(x, y, z)
				local k = SU.kind(ctx.get(p))
				if k == "clear" or k == "liquid" or (cut and k == "ground") then
					ctx.set(p, "air")
				end
			end
		end
	end
end

VL.ground_piece = ground_piece

local function path_piece(ctx, leg, rects, palette)
	local path = VP.get(palette, "path")
	for x = leg[1], leg[3] do
		for z = leg[2], leg[4] do
			local inside = false
			for _, r in ipairs(rects) do
				inside = inside or (x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4])
			end
			if not inside then
				for y = leg[6], leg[5], -1 do
					local p = vector.new(x, y, z)
					local k = SU.kind(ctx.get(p))
					if k == "ground" then
						ctx.set(p, path)
						local above = vector.offset(p, 0, 1, 0)
						if SU.kind(ctx.get(above)) == "clear" then
							ctx.set(above, "air")
						end
						break
					elseif k ~= "air" and k ~= "clear" then
						break
					end
				end
			end
		end
	end
end

function VL.layout(origin, seed, plan)
	local pieces, rects = {}, {}
	local lo, hi
	local function grow(a, b)
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	for i, b in ipairs(plan.b) do
		local s = VS.get(b.n)
		local w, d = VS.footprint(s, b.k)
		local minp = vector.new(b.x, b.y, b.z)
		local fmin = vector.offset(minp, 0, -VL.FOUNDATION, 0)
		local fmax = vector.offset(minp, w - 1, s.y + VL.CLEAR, d - 1)
		rects[#rects + 1] = { b.x, b.z, b.x + w - 1, b.z + d - 1, }
		pieces[#pieces + 1] = { minp = fmin, maxp = fmax, build = function(ctx)
			ground_piece(ctx, fmin, fmax, minp.y, plan.v)
		end, }
		local kind = i == 1 and "center" or (s.beds > 0 and "house" or nil)
		local loot = VL.loot_for(b.n, plan.v)
		pieces[#pieces + 1] = { minp = minp, maxp = vector.offset(minp, w - 1, s.y, d - 1), part = kind ~= nil,
			kind = kind, build = function(ctx)
				local info = VS.place(ctx, s, minp, b.k, plan.v, loot)
				ctx.after(function()
					for _, fn in ipairs(VL.on_built) do
						fn(kind, info, plan)
					end
				end)
			end, }
		grow(fmin, fmax)
	end
	for _, leg in ipairs(plan.p) do
		local a, b = vector.new(leg[1], leg[5], leg[2]), vector.new(leg[3], leg[6], leg[4])
		pieces[#pieces + 1] = { minp = a, maxp = b, build = function(ctx)
			path_piece(ctx, leg, rects, plan.v)
		end, }
		grow(a, b)
	end
	return { minp = lo, maxp = hi, pieces = pieces, plan = plan, }
end

local VILLAGER, GOLEM = "cb_mobs_village:villager", "cb_mobs_village:iron_golem"

-- A villager belongs to the house its bed is in (it may walk 24 nodes away).
local function owns(ent, part)
	return ent._bed ~= nil and cb_core.inside(ent._bed, part.minp, part.maxp)
end

-- A villager that respawns in a house takes a free bed of that house (its
-- own search may not reach a bed on another floor).
local function give_bed(ent, part)
	for _, bed in ipairs(core.find_nodes_in_area(part.minp, part.maxp, { "beds:bed_bottom", })) do
		if not cb_mobs_village.claimed(bed, ent) then
			ent._bed = bed
			return
		end
	end
end

VL.MIN_VILLAGERS = 2

-- Villagers in the village box (with the 24-node margin they may walk).
function VL.villagers(rec)
	local n = 0
	for _, obj in ipairs(core.get_objects_in_area(vector.subtract(rec.minp, 24), vector.add(rec.maxp, 24))) do
		local e = obj:get_luaentity()
		if e and e.name == VILLAGER then
			n = n + 1
		end
	end
	return n
end

-- One lookup for "the village at pos" (spec cycle 5, 4.3-4.4): a generated
-- village reaches JOIN nodes past its box (players' houses there join it), a
-- player's village is its box (32 around the bell). Raids, the trader,
-- breeding and golems all go through VL.find.
VL.JOIN, VL.JOIN_Y, VL.HOUSE_DOOR, VL.BEDS_TTL = 32, 16, 8, 30

local function reach(rec)
	if rec.player then
		return rec.minp, rec.maxp
	end
	return vector.offset(rec.minp, -VL.JOIN, -VL.JOIN_Y, -VL.JOIN), vector.offset(rec.maxp, VL.JOIN, VL.JOIN_Y, VL.JOIN)
end

function VL.find(pos)
	local fid, frec
	cb_structures.registry.parts_near(pos, 64, function(id, _, rec)
		if rec.type == "village" and rec.state == "ready" then
			local lo, hi = reach(rec)
			if cb_core.inside(pos, lo, hi) then
				fid, frec = id, rec
				return false
			end
		end
	end)
	return fid, frec
end

-- The village's beds: every bed in a generated village's box, and beds with
-- a wooden door within HOUSE_DOOR elsewhere in its reach (players' houses;
-- every bed of a player's village needs one). Cached BEDS_TTL s.
local beds_cache = setmetatable({}, { __mode = "k", })

function VL.beds(id, rec)
	local now = core.get_gametime()
	local c = beds_cache[rec]
	if c and now - c.t < VL.BEDS_TTL then
		return c.beds
	end
	local lo, hi = reach(rec)
	local beds = {}
	for _, bed in ipairs(core.find_nodes_in_area(lo, hi, { "beds:bed_bottom", })) do
		if (not rec.player and cb_core.inside(bed, rec.minp, rec.maxp))
				or (cb_core.doors and #cb_core.doors.near(bed, VL.HOUSE_DOOR) > 0) then
			beds[#beds + 1] = bed
		end
	end
	beds_cache[rec] = { t = now, beds = beds, }
	return beds
end

function VL.forget_beds(rec)
	beds_cache[rec] = nil
end

-- The bell of a village: a player's village keeps it, a generated one has it
-- in its centre part (if nobody broke it).
function VL.bell(rec)
	if rec.bell then
		return rec.bell
	end
	for _, part in ipairs(rec.parts or {}) do
		if part.k == "center" then
			local b = core.find_nodes_in_area(part.minp, part.maxp, { "group:cb_bell", })[1]
			if b then
				return b
			end
		end
	end
end

local function golems(rec)
	return math.max(1, math.floor(#VL.beds(nil, rec) / 10))
end

-- The village around pos and its beds (breeding).
if rawget(_G, "cb_mobs_village") then
	cb_mobs_village.village_at = function(pos)
		local id, rec = VL.find(pos)
		if not id then
			return nil
		end
		return { id = id, minp = rec.minp, maxp = rec.maxp, beds = VL.beds(id, rec), bell = VL.bell(rec), }
	end
end

-- A villager per bed of a new house, bound to its bed.
table.insert(VL.on_built, function(kind, info)
	if kind ~= "house" or not core.registered_entities[VILLAGER] then
		return
	end
	for _, bed in ipairs(info.beds) do
		local obj = core.add_entity(vector.offset(cb_mobs_village.bed_side(bed), 0, 0.5, 0), VILLAGER)
		local ent = obj and obj:get_luaentity()
		if ent then
			ent._bed = bed
		end
	end
end)

-- Doors zombies break inside a village come back the next morning (spec
-- cycle 4, 8a): noted in the part (saved with the record), put back by the
-- respawn engine's restock call when both nodes are free.
function VL.note_broken_door(pos, info)
	local noted = false
	cb_structures.registry.parts_near(pos, 0, function(id, _, rec, part)
		if not noted and rec.type == "village" and cb_core.inside(pos, part.minp, part.maxp) then
			part.doors = part.doors or {}
			table.insert(part.doors, { p = vector.copy(pos), n = info.n, r = info.r, h = info.h, s = info.s,
				d = core.get_day_count(), })
			cb_structures.registry.save(id)
			noted = true
			return false
		end
	end)
	return noted
end

function VL.restock(rec, part, id)
	if not part.doors or #part.doors == 0 then
		return
	end
	local tod, day = core.get_timeofday(), core.get_day_count()
	if tod < 0.23 or tod > 0.5 then
		return
	end
	local keep = {}
	for _, e in ipairs(part.doors) do
		local top = vector.offset(e.p, 0, 1, 0)
		local a, b = core.get_node(e.p).name, core.get_node(top).name
		if a == "ignore" or b == "ignore" or day <= e.d then
			keep[#keep + 1] = e
		elseif a == "air" and b == "air" and core.registered_nodes[e.n] then
			core.set_node(e.p, { name = e.n, param2 = e.r, })
			core.set_node(top, { name = "doors:hidden", param2 = e.h, })
			core.get_meta(e.p):set_int("state", e.s or 0)
		end
	end
	part.doors = #keep > 0 and keep or nil
	cb_structures.registry.save(id)
end

cb_structures.register("village", {
	description = S("Village"),
	dims = { "overworld", },
	variants = cb_core.PALETTES,
	pick_variant = cb_core.biome_palette,
	prepare = { radius = VL.RADIUS + 16, below = VL.SCAN_DOWN, above = VL.SCAN_UP, },
	plan = VL.plan,
	layout = VL.layout,
	self_checked = true,
	restock = VL.restock,
	inhabitants = { kinds = {
		house = { mobs = { { VILLAGER, 1, }, }, anchors = { "beds:bed_bottom", }, count = true, margin = 24, owns = owns,
			on_spawn = give_bed, when = function(rec) return not rec.player and VL.villagers(rec) < VL.MIN_VILLAGERS end, },
		center = { mobs = { { GOLEM, 1, }, }, anchors = { "cb_blocks:bell", }, norm = golems, margin = 24,
			on_spawn = function(ent, _, rec) ent._home = VL.bell(rec) or false end, },
	}, },
})
