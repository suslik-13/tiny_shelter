-- End pocket generator: a void with the main island (an end stone lens) in the
-- centre, ten obsidian pillars with bedrock tops (two caged), the exit portal
-- frame in the middle, the entry platform and a ring of outer islands. Every
-- shape is a function of the node position, so any mapblock can be written
-- alone and in any order.
if not cb_dimensions.get_dim("end") then
	return
end

local E = cb_core.equiv
local the_end = {}
cb_dimensions.the_end = the_end

the_end.ISLAND_R = 75
the_end.PILLAR_RING = 40
the_end.PLATFORM_D = 50
the_end.VOID = 8
the_end.EDGE = 16
the_end.OUTER_R = tonumber(cb_core.setting("cubeborn.end_outer_r", "")) or (cb_core.profile.nether == "own" and 150 or 400)

local NP_ISLAND = { offset = 0, scale = 1, spread = { x = 24, y = 24, z = 24, }, seed = 7711, octaves = 2,
	persistence = 0.5, lacunarity = 2, }
local NP_OUTER = { offset = 0, scale = 1, spread = { x = 48, y = 48, z = 48, }, seed = 3307, octaves = 3,
	persistence = 0.5, lacunarity = 2, }
local NP_OUTER_Y = { offset = 0, scale = 1, spread = { x = 96, y = 96, z = 96, }, seed = 9104, octaves = 1,
	persistence = 0.5, lacunarity = 2, }

local perlin = {}
local function point(np, x, z)
	local p = perlin[np]
	if not p then
		p = core.get_perlin(np)
		perlin[np] = p
	end
	return p:get_2d({ x = x, y = z, })
end

local world_seed = tonumber((core.get_mapgen_setting("seed") or "0"):sub(-9)) or 0
function the_end.seed_of(x, y, z)
	return world_seed + x * 1000003 + y * 4099 + z * 37
end

function the_end.geometry(pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	local cx, cz = math.floor((ia.x + ib.x) / 2), math.floor((ia.z + ib.z) / 2)
	local yc = ia.y + math.floor((ib.y - ia.y + 1) * 0.45)
	local g = {
		ia = ia, ib = ib, centre = vector.new(cx, yc, cz), pillars = {},
		platform = vector.new(cx + the_end.PLATFORM_D, yc + 4, cz), outer_r = the_end.OUTER_R,
	}
	for k = 0, 9 do
		local a = k * math.pi / 5
		g.pillars[k + 1] = {
			x = cx + math.floor(the_end.PILLAR_RING * math.cos(a) + 0.5),
			z = cz + math.floor(the_end.PILLAR_RING * math.sin(a) + 0.5),
			r = 2 + k % 3,
			h = 20 + (k * 7) % 21,
			cage = k == 1 or k == 6,
		}
	end
	return g
end

function the_end.island_range(g, x, z)
	local dx, dz = x - g.centre.x, z - g.centre.z
	local r = the_end.ISLAND_R + 8 * point(NP_ISLAND, x, z)
	local d2 = dx * dx + dz * dz
	if d2 >= r * r then
		return nil
	end
	local f = 1 - d2 / (r * r)
	return g.centre.y - math.floor(36 * f ^ 0.7), g.centre.y + math.floor(2 * f)
end

function the_end.outer_range(g, x, z)
	local dx, dz = x - g.centre.x, z - g.centre.z
	if dx * dx + dz * dz < g.outer_r * g.outer_r then
		return nil
	end
	local edge = the_end.EDGE
	if x < g.ia.x + edge or x > g.ib.x - edge or z < g.ia.z + edge or z > g.ib.z - edge then
		return nil
	end
	local n = point(NP_OUTER, x, z)
	if n <= 0.5 then
		return nil
	end
	local t = math.min((n - 0.5) * 40, 16)
	local ys = g.centre.y + math.floor(point(NP_OUTER_Y, x, z) * 24)
	return ys - math.floor(t), ys + math.floor(t / 4)
end

function the_end.exit_portal_nodes(g)
	local list = {}
	for dx = -2, 2 do
		for dz = -2, 2 do
			local d2 = dx * dx + dz * dz
			if d2 >= 1 and d2 <= 6 then
				list[#list + 1] = vector.offset(g.centre, dx, 3, dz)
			end
		end
	end
	return list
end

local c
function the_end.cids()
	if c then
		return c
	end
	local id = core.get_content_id
	c = {
		air = core.CONTENT_AIR, stone = id("cb_blocks:end_stone"), bedrock = id("cb_blocks:end_bedrock"),
		obsidian = id(E("obsidian")),
		bars = core.registered_nodes["xpanes:bar"] and id("xpanes:bar") or nil,
	}
	return c
end

cb_core.register_natural(E("obsidian"), "pocket")
if core.registered_nodes["xpanes:bar"] then
	cb_core.register_natural("xpanes:bar", "pocket")
end

-- The node a pillar has at (dx, dz) from its axis and height y, or nil.
function the_end.pillar_node(p, dx, dz, y, cy, ids)
	local top = cy + p.h
	if dx * dx + dz * dz <= p.r * p.r and y >= cy - 10 and y <= top then
		return ids.obsidian
	elseif dx == 0 and dz == 0 and y == top + 1 then
		return ids.bedrock
	elseif p.cage and ids.bars and math.abs(dx) <= 2 and math.abs(dz) <= 2 and y >= top + 1 and y <= top + 4
			and (math.abs(dx) == 2 or math.abs(dz) == 2 or y == top + 4) then
		return ids.bars
	end
	return nil
end

function the_end.generate(data, va, lo, hi, pocket)
	local ids = the_end.cids()
	local g = the_end.geometry(pocket)
	local cy = g.centre.y
	local ystride = va.ystride
	for z = lo.z, hi.z do
		for x = lo.x, hi.x do
			local ilo, ihi = the_end.island_range(g, x, z)
			local olo, ohi = the_end.outer_range(g, x, z)
			local dx, dz = x - g.centre.x, z - g.centre.z
			local d2 = dx * dx + dz * dz
			local pil, pdx, pdz
			for _, p in ipairs(g.pillars) do
				if math.abs(x - p.x) <= 4 and math.abs(z - p.z) <= 4 then
					pil, pdx, pdz = p, x - p.x, z - p.z
					break
				end
			end
			local plat = math.abs(x - g.platform.x) <= 2 and math.abs(z - g.platform.z) <= 2
			local vi = va:index(x, lo.y, z)
			for y = lo.y, hi.y do
				local id = ids.air
				if (ilo and y >= ilo and y <= ihi) or (olo and y >= olo and y <= ohi) then
					id = ids.stone
				end
				if d2 <= 12 then
					if y == cy + 2 or (y == cy + 3 and d2 >= 7) or (d2 == 0 and y >= cy + 3 and y <= cy + 6) then
						id = ids.bedrock
					elseif y > cy + 2 then
						id = ids.air
					end
				end
				if pil then
					id = the_end.pillar_node(pil, pdx, pdz, y, cy, ids) or id
				end
				if plat then
					if y == g.platform.y then
						id = ids.obsidian
					elseif y > g.platform.y and y <= g.platform.y + 3 then
						id = ids.air
					end
				end
				data[vi] = id
				vi = vi + ystride
			end
		end
	end
end

cb_dimensions.set_generator("end", the_end.generate)
