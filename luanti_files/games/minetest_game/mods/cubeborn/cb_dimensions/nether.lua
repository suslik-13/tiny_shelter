-- Nether pocket generator (profile "own"): 3D-noise caverns between a solid
-- floor and ceiling, a lava sea, five biomes picked per column from 2D
-- temperature/humidity noise, ores. Deterministic per node position.
if not cb_dimensions.get_dim("nether") then
	return
end

local E = cb_core.equiv
local nether = {}
cb_dimensions.nether = nether

nether.LAVA_LEVEL = 31
local FLOOR_FADE, CEIL_FADE, FADE_GAIN, CAVE_BIAS = 24, 20, 2.5, 0.15
local EXTRA = 4 -- density rows above the box, to tell surface from filler

local NP_DENSITY = { offset = 0, scale = 1, spread = { x = 96, y = 48, z = 96, }, seed = 5911, octaves = 3,
	persistence = 0.5, lacunarity = 2, }
local NP_TEMP = { offset = 0, scale = 1, spread = { x = 160, y = 160, z = 160, }, seed = 8321, octaves = 2,
	persistence = 0.5, lacunarity = 2, }
local NP_HUMID = { offset = 0, scale = 1, spread = { x = 160, y = 160, z = 160, }, seed = 1271, octaves = 2,
	persistence = 0.5, lacunarity = 2, }
local NP_SURF = { offset = 0, scale = 1, spread = { x = 12, y = 12, z = 12, }, seed = 4401, octaves = 1,
	persistence = 0.5, lacunarity = 2, }

-- Biome points in (temperature, humidity) space; the nearest one wins.
nether.BIOMES = {
	{ name = "nether_wastes", t = 0, h = 0, },
	{ name = "soul_sand_valley", t = 0, h = -0.6, },
	{ name = "crimson_forest", t = 0.6, h = 0, },
	{ name = "warped_forest", t = 0, h = 0.6, },
	{ name = "basalt_deltas", t = -0.6, h = 0, },
}

function nether.pick_biome(t, h)
	local best, best_d
	for _, b in ipairs(nether.BIOMES) do
		local d = (t - b.t) ^ 2 + (h - b.h) ^ 2
		if not best_d or d < best_d then
			best, best_d = b.name, d
		end
	end
	return best
end

local perlin = {}
local function point_noise(np)
	local p = perlin[np]
	if not p then
		p = core.get_perlin(np)
		perlin[np] = p
	end
	return p
end

function nether.biome_at(x, z)
	local p = { x = x, y = z, }
	return nether.pick_biome(point_noise(NP_TEMP):get_2d(p), point_noise(NP_HUMID):get_2d(p))
end

-- A 2D map has no sz: its size.z is 1 (Luanti 5.18 rejects a nil coordinate).
local maps = {}
local function noise_map(np, sx, sy, sz)
	sz = sz or 1
	local key = np.seed .. ":" .. sx .. ":" .. sy .. ":" .. sz
	local m = maps[key]
	if not m then
		m = core.get_perlin_map(np, { x = sx, y = sy, z = sz, })
		maps[key] = m
	end
	return m
end

local c
function nether.cids()
	if c then
		return c
	end
	local id = core.get_content_id
	c = {
		air = core.CONTENT_AIR, lava = id("default:lava_source"), rack = id(E("netherrack")),
		quartz = id("cb_blocks:quartz_ore"), gold = id("cb_blocks:nether_gold_ore"),
		debris = id("cb_blocks:ancient_debris"), magma = id("cb_blocks:magma"),
		soul_sand = id("cb_blocks:soul_sand"), soul_soil = id("cb_blocks:soul_soil"),
		basalt = id(E("basalt")), blackstone = id("cb_blocks:blackstone"),
		crimson_nylium = id("cb_blocks:crimson_nylium"), warped_nylium = id("cb_blocks:warped_nylium"),
	}
	c.ground = {}
	for _, k in ipairs({ "rack", "quartz", "gold", "debris", "magma", "soul_sand", "soul_soil", "basalt",
		"blackstone", "crimson_nylium", "warped_nylium", }) do
		c.ground[c[k]] = true
	end
	return c
end

local world_seed = tonumber((core.get_mapgen_setting("seed") or "0"):sub(-9)) or 0
function nether.seed_of(x, y, z)
	return world_seed + x * 1000003 + y * 4099 + z * 37
end

local function solid(n, yr, height)
	local d = n - CAVE_BIAS
	local f = 1 - yr / FLOOR_FADE
	if f > 0 then
		d = d + f * FADE_GAIN
	end
	f = 1 - (height - 1 - yr) / CEIL_FADE
	if f > 0 then
		d = d + f * FADE_GAIN
	end
	return d > 0
end

-- Surface rule of a biome: top block, filler block, filler depth.
local function surface(biome, s)
	if biome == "crimson_forest" then
		return c.crimson_nylium, c.rack, 1
	elseif biome == "warped_forest" then
		return c.warped_nylium, c.rack, 1
	elseif biome == "soul_sand_valley" then
		return s > 0 and c.soul_sand or c.soul_soil, c.soul_soil, 3
	elseif biome == "basalt_deltas" then
		return s > 0.3 and c.blackstone or c.basalt, c.basalt, 6
	end
	return c.rack, c.rack, 1
end

local dbuf, tbuf, hbuf, sbuf = {}, {}, {}, {}

function nether.generate(data, va, lo, hi, pocket)
	nether.cids()
	local ia, ib = cb_dimensions.inner(pocket)
	local height = ib.y - ia.y + 1
	local lava_y = ia.y + nether.LAVA_LEVEL
	local sx, sy, sz = hi.x - lo.x + 1, hi.y - lo.y + 1, hi.z - lo.z + 1
	local ny = sy + EXTRA
	-- A map with size.z == 1 is 2D in Luanti; the extra z layer is ignored.
	local dens = noise_map(NP_DENSITY, sx, ny, math.max(sz, 2)):get_3d_map_flat(lo, dbuf)
	local p2 = { x = lo.x, y = lo.z, }
	local temp = noise_map(NP_TEMP, sx, sz):get_2d_map_flat(p2, tbuf)
	local humid = noise_map(NP_HUMID, sx, sz):get_2d_map_flat(p2, hbuf)
	local surf = noise_map(NP_SURF, sx, sz):get_2d_map_flat(p2, sbuf)
	local zstride = sx * ny
	local ystride = va.ystride
	for z = lo.z, hi.z do
		for x = lo.x, hi.x do
			local rng = PcgRandom(nether.seed_of(x, lo.y, z))
			local i2 = (z - lo.z) * sx + (x - lo.x) + 1
			local biome = nether.pick_biome(temp[i2], humid[i2])
			local s = surf[i2]
			local top, filler, depth = surface(biome, s)
			local col = (z - lo.z) * zstride + (x - lo.x) + 1
			local run, lava_above = 0, false
			for y = hi.y + EXTRA, hi.y + 1, -1 do
				if solid(dens[col + (y - lo.y) * sx], y - ia.y, height) then
					run = run + 1
				else
					run, lava_above = 0, y <= lava_y
				end
			end
			local vi = va:index(x, hi.y, z)
			for y = hi.y, lo.y, -1 do
				local yr = y - ia.y
				local id
				if solid(dens[col + (y - lo.y) * sx], yr, height) then
					run = run + 1
					local r = rng:next(1, 10000)
					if run == 1 and not lava_above then
						id = top
						if biome == "basalt_deltas" then
							if r <= 800 then
								id = c.magma
							elseif s > 0.75 then
								id = c.lava
							end
						end
					elseif run <= depth + 1 and not lava_above then
						id = filler
					else
						id = c.rack
						if r <= 120 then
							id = c.quartz
						elseif r <= 200 then
							id = c.gold
						elseif r > 9996 and yr >= 8 and yr <= 22 then
							id = c.debris
						elseif r <= 1200 and yr >= nether.LAVA_LEVEL - 3 and yr <= nether.LAVA_LEVEL + 1 then
							id = c.magma
						end
					end
				else
					run = 0
					lava_above = y <= lava_y
					id = lava_above and c.lava or c.air
				end
				data[vi] = id
				vi = vi - ystride
			end
		end
	end
end

cb_dimensions.set_generator("nether", nether.generate)
