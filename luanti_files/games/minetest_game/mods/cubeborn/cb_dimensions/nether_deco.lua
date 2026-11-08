-- Nether decorations, placed by the fill job's decorate phase after the
-- terrain: glowstone under the ceiling, fire, fungi and huge fungi, roots,
-- sprouts, vines and basalt pillars. Features only replace air. Every surface
-- draws one roll from its column's generator and every feature has its own
-- position-seeded generator, so decorating a piece again changes nothing.
local nether = cb_dimensions.nether
if not nether then
	return
end
local E = cb_core.equiv
local AIR = core.CONTENT_AIR

local d
function nether.deco_ids()
	if d then
		return d
	end
	local id = core.get_content_id
	d = {
		glow = id(E("glowstone")),
		fire = core.registered_nodes["fire:permanent_flame"] and id("fire:permanent_flame") or nil,
		soul_fire = id("cb_blocks:soul_fire"),
		basalt = id(E("basalt")),
		shroomlight = id("cb_blocks:shroomlight"),
		weeping = id("cb_blocks:weeping_vines"),
		twisting = id("cb_blocks:twisting_vines"),
		sprouts = id("cb_blocks:nether_sprouts"),
		crimson = { stem = id("cb_blocks:crimson_stem"), cap = id("cb_blocks:nether_wart_block"),
			fungus = id("cb_blocks:crimson_fungus"), roots = id("cb_blocks:crimson_roots"), },
		warped = { stem = id("cb_blocks:warped_stem"), cap = id("cb_blocks:warped_wart_block"),
			fungus = id("cb_blocks:warped_fungus"), roots = id("cb_blocks:warped_roots"), },
	}
	return d
end

function nether.put(data, va, mlo, mhi, x, y, z, id)
	if x < mlo.x or x > mhi.x or y < mlo.y or y > mhi.y or z < mlo.z or z > mhi.z then
		return false
	end
	local i = va:index(x, y, z)
	if data[i] ~= AIR then
		return false
	end
	data[i] = id
	return true
end
local put = nether.put

local function column(data, va, mlo, mhi, x, y, z, dy, len, id)
	for k = 0, len - 1 do
		if not put(data, va, mlo, mhi, x, y + k * dy, z, id) then
			return
		end
	end
end

local CAP = { { dy = 1, r = 1, }, { dy = 0, r = 2, }, { dy = -1, r = 2, ring = true, }, { dy = -2, r = 3, ring = true, }, }

function nether.huge_fungus(data, va, mlo, mhi, x, y, z, kind, rng)
	local ids = nether.deco_ids()
	local k = ids[kind]
	local h = rng:next(4, 9)
	column(data, va, mlo, mhi, x, y, z, 1, h, k.stem)
	local top = y + h - 1
	for _, layer in ipairs(CAP) do
		for dx = -layer.r, layer.r do
			for dz = -layer.r, layer.r do
				if not layer.ring or math.abs(dx) == layer.r or math.abs(dz) == layer.r then
					local id = rng:next(1, 12) == 1 and ids.shroomlight or k.cap
					put(data, va, mlo, mhi, x + dx, top + layer.dy, z + dz, id)
				end
			end
		end
	end
	if kind == "crimson" then
		for _ = 1, 4 do
			local vx, vz = x + rng:next(-3, 3), z + rng:next(-3, 3)
			column(data, va, mlo, mhi, vx, top - 3, vz, -1, rng:next(1, 4), ids.weeping)
		end
	end
end

local DIRS = { { 1, 0, 0, }, { -1, 0, 0, }, { 0, 0, 1, }, { 0, 0, -1, }, { 0, -1, 0, }, { 0, -1, 0, }, }

function nether.glowstone_blob(data, va, mlo, mhi, x, y, z, rng)
	local glow = nether.deco_ids().glow
	if not put(data, va, mlo, mhi, x, y, z, glow) then
		return
	end
	local list = { { x, y, z, }, }
	for _ = 1, rng:next(6, 20) do
		local p = list[rng:next(1, #list)]
		local dir = DIRS[rng:next(1, #DIRS)]
		local q = { p[1] + dir[1], p[2] + dir[2], p[3] + dir[3], }
		if put(data, va, mlo, mhi, q[1], q[2], q[3], glow) then
			list[#list + 1] = q
		end
	end
end

-- (x, y, z) is the air node above a ground node `under`.
local function floor_feature(data, va, mlo, mhi, x, y, z, under, biome, r, c, ids)
	local frng = PcgRandom(nether.seed_of(x, y, z) + 11)
	if biome == "crimson_forest" and under == c.crimson_nylium then
		if r <= 20 then
			nether.huge_fungus(data, va, mlo, mhi, x, y, z, "crimson", frng)
		elseif r <= 80 then
			put(data, va, mlo, mhi, x, y, z, ids.crimson.fungus)
		elseif r <= 200 then
			put(data, va, mlo, mhi, x, y, z, ids.crimson.roots)
		end
	elseif biome == "warped_forest" and under == c.warped_nylium then
		if r <= 20 then
			nether.huge_fungus(data, va, mlo, mhi, x, y, z, "warped", frng)
		elseif r <= 70 then
			put(data, va, mlo, mhi, x, y, z, ids.warped.fungus)
		elseif r <= 170 then
			put(data, va, mlo, mhi, x, y, z, ids.warped.roots)
		elseif r <= 230 then
			put(data, va, mlo, mhi, x, y, z, ids.sprouts)
		elseif r <= 245 then
			column(data, va, mlo, mhi, x, y, z, 1, frng:next(1, 8), ids.twisting)
		end
	elseif biome == "soul_sand_valley" then
		if r <= 10 and under == c.soul_soil then
			put(data, va, mlo, mhi, x, y, z, ids.soul_fire)
		elseif r >= 995 then
			column(data, va, mlo, mhi, x, y, z, 1, frng:next(3, 12), ids.basalt)
		end
	elseif biome == "nether_wastes" and under == c.rack and r <= 12 and ids.fire then
		put(data, va, mlo, mhi, x, y, z, ids.fire)
	end
end

-- (x, y, z) is the air node under a ground node of the ceiling.
local function ceiling_feature(data, va, mlo, mhi, x, y, z, biome, r, ids)
	if r <= 6 then
		nether.glowstone_blob(data, va, mlo, mhi, x, y, z, PcgRandom(nether.seed_of(x, y, z) + 13))
	elseif biome == "crimson_forest" and r <= 60 then
		column(data, va, mlo, mhi, x, y, z, -1, 1 + r % 6, ids.weeping)
	end
end

function nether.decorate(data, va, lo, hi, mlo, mhi, pocket)
	local c, ids = nether.cids(), nether.deco_ids()
	local ground = c.ground
	local ystride = va.ystride
	for z = lo.z, hi.z do
		for x = lo.x, hi.x do
			local biome = nether.biome_at(x, z)
			local rng = PcgRandom(nether.seed_of(x, lo.y, z))
			-- A surface is the pair (y - 1, y); the bottom row of a piece pairs with
			-- the row below it when that row is inside the writable box.
			local y1 = math.max(lo.y, mlo.y + 1)
			local vi = va:index(x, y1 - 1, z)
			for y = y1, hi.y do
				local below = data[vi]
				vi = vi + ystride
				local cur = data[vi]
				if ground[below] and not ground[cur] then
					local r = rng:next(1, 1000)
					if cur == AIR then
						floor_feature(data, va, mlo, mhi, x, y, z, below, biome, r, c, ids)
					end
				elseif ground[cur] and not ground[below] then
					local r = rng:next(1, 1000)
					if below == AIR then
						ceiling_feature(data, va, mlo, mhi, x, y - 1, z, biome, r, ids)
					end
				end
			end
		end
	end
end

cb_dimensions.set_decorator("nether", nether.decorate)
