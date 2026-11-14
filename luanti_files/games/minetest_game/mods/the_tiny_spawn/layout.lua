-- Spawn design: symmetric road skeleton + 8 unique districts.
--
-- Coordinates are relative to the spawn centre: x (east), z (north),
-- h = height above the floor (h = 0 is the floor layer).
--
-- Only the ROADS are symmetric (as on the old spawn): 4 rail avenues on the
-- axes, a ring road, diagonal paths inside the ring and diagonal roads to the
-- corners, a walkway along the square border.  Each of the 8 sectors between
-- the roads is a different hand-styled district (see districts.lua).

local MN = "the_tiny_spawn:"
local B = dofile(minetest.get_modpath("the_tiny_spawn") .. "/lib.lua")
local D = dofile(minetest.get_modpath("the_tiny_spawn") .. "/districts.lua")
local L = {}

local sqrt, floor, abs, atan2, pi = math.sqrt, math.floor, math.abs, math.atan2, math.pi
local function round(v) return floor(v + 0.5) end
local GRASS = "default:dirt_with_grass"

function L.geometry(R)
	local g = {R = R}
	g.CW = 3                   -- rail avenue half width (7 nodes)
	g.PL = 13                  -- central plaza radius
	g.RR = round(R * 0.72)     -- ring road centre radius
	g.GU = R - 6               -- gate position along the avenue
	g.HCLEAR = 48              -- everything up to this height is cleared
	g.s = R / 60               -- district placement scale
	return g
end

-- 8 symmetry frames: local (u, v) with u >= v >= 0  ->  world (x, z)
local SYM8, ROT4 = {}, {}
for _, m in ipairs({{1, 0, 0, 1}, {0, -1, 1, 0}, {-1, 0, 0, -1}, {0, 1, -1, 0}}) do
	ROT4[#ROT4 + 1] = m
	SYM8[#SYM8 + 1] = m
	SYM8[#SYM8 + 1] = {m[1], -m[2], m[3], -m[4]}
end
L.SYM8 = SYM8

-- which frame (1..8) a world cell belongs to
local function frame_of(x, z)
	for i, m in ipairs(SYM8) do
		local u, v = m[1] * x + m[3] * z, m[2] * x + m[4] * z   -- transpose = inverse
		if u >= v and v >= 0 then return i, u, v end
	end
	return 1, x, z
end
L.frame_of = frame_of

------------------------------------------------------------------------------
-- buildable room (distance to the nearest road / edge; <= 0 = not buildable)
------------------------------------------------------------------------------
function L.room(g, x, z)
	local R, RR = g.R, g.RR
	local ax, az = abs(x), abs(z)
	local u, v = math.max(ax, az), math.min(ax, az)
	local r = sqrt(x * x + z * z)
	local d = (u - v) / sqrt(2)
	local room
	if r < RR - 4 then
		room = math.min(v - 4.5, d - 2.3, (RR - 4) - r, r - (g.PL + 0.5))
	elseif r > RR + 4 then
		room = math.min(v - 4.5, d - 3.5, r - (RR + 4.5), (R - 3.5) - u)
		if u >= g.GU - 2 and v <= 17 then room = math.min(room, 0) end
	else
		room = -1
	end
	return room
end

------------------------------------------------------------------------------
-- floor plan
------------------------------------------------------------------------------
function L.floor_at(g, x, z)
	local R, CW, PL, RR = g.R, g.CW, g.PL, g.RR
	local ax, az = abs(x), abs(z)
	local u, v = math.max(ax, az), math.min(ax, az)
	local r = sqrt(x * x + z * z)
	local d = (u - v) / sqrt(2)
	local dr = abs(r - RR)
	local theta = atan2(v, u)

	if r <= 2.6 then return MN .. "emitter" end

	-- central plaza with a water ring and 8 bridges
	if r <= PL then
		if r <= 3.6 then return "default:silver_sandstone_block" end
		if r <= 4.6 then return MN .. "neon_cyan" end
		local bridge = v <= 1 or d <= 1.1
		if r <= 7.4 then
			if bridge then return "default:silver_sandstone_brick" end
			return "default:water_source"
		end
		if r <= 8.4 then return "default:stone_block" end
		if r >= PL - 0.6 then return MN .. "neon_magenta" end
		if v <= 1 then return "default:silver_sandstone_brick" end
		local petal = floor(theta * 16 / (2 * pi) * 4 + r / 2.2) % 2
		return petal == 0 and "default:silver_sandstone_brick" or "default:stonebrick"
	end

	-- square border: wall + walkway
	if u >= R then return "default:stonebrick" end
	if u >= R - 3 then return B.mix(B.PAVE_WARM, x, z, 3) end

	-- rail avenues (N/E/S/W)
	if v <= CW then
		if v == 0 then return "default:silver_sandstone_brick" end
		if v == CW then return "default:stone_block" end
		return B.mix(B.PAVE, x, z, 1)
	end
	if v == CW + 1 and dr > 4 then return MN .. "neon_cyan" end

	-- ring road (cyber asphalt with yellow edges, a nod to the old spawn)
	if dr <= 0.5 then
		local dash = floor(theta * RR / 2.5) % 2
		return dash == 0 and MN .. "road_line" or MN .. "road"
	end
	if dr <= 3 then return MN .. "road" end
	if dr <= 4 then return MN .. "neon_yellow" end

	if r > RR then
		-- diagonal roads to the corners
		if d <= 0.5 then return "default:silver_sandstone_brick" end
		if d <= 2.6 then return B.mix(B.PAVE, x, z, 2) end
		if d <= 3.4 then return MN .. "neon_magenta" end
		return GRASS, true
	end
	-- diagonal footpaths inside the ring
	if d <= 1.5 then return B.mix(B.PAVE_WARM, x, z, 4) end
	if d <= 2.2 then return MN .. "neon_purple" end
	return GRASS, true
end

------------------------------------------------------------------------------
-- skeleton structures
------------------------------------------------------------------------------
local function put(P, m, u, h, v, name, p2)
	P.set(m[1] * u + m[2] * v, h, m[3] * u + m[4] * v, name, p2)
end

local function plaza(P, b, g)
	-- rim slabs around the water ring (gaps at the bridges)
	for x = -9, 9 do for z = -9, 9 do
		local r = sqrt(x * x + z * z)
		local u, v = math.max(abs(x), abs(z)), math.min(abs(x), abs(z))
		local bridge = v <= 1 or (u - v) / sqrt(2) <= 1.1
		if r > 7.4 and r <= 8.4 and not bridge then
			P.set(x, 1, z, "stairs:slab_silver_sandstone_brick")
		end
	end end
	for _, m in ipairs(SYM8) do
		-- lantern columns between the bridges
		local a = 22.5 * pi / 180
		local cu, cv = round(10.5 * math.cos(a)), round(10.5 * math.sin(a))
		put(P, m, cu, 1, cv, "default:stonebrick")
		put(P, m, cu, 2, cv, MN .. "light_pillar")
		put(P, m, cu, 3, cv, MN .. "light_pillar")
		put(P, m, cu, 4, cv, "default:silver_sandstone_block")
		put(P, m, cu, 5, cv, MN .. "solar_lantern")
		-- fountain jets in the water
		local ju, jv = round(6 * math.cos(a)), round(6 * math.sin(a))
		for h = 1, 3 do put(P, m, ju, h, jv, MN .. "holo_column") end
		-- waterlilies
		local lu, lv = round(5.4 * math.cos(a * 1.6)), round(5.4 * math.sin(a * 1.6))
		if lu ~= ju or lv ~= jv then put(P, m, lu, 1, lv, "flowers:waterlily", 0) end
		-- benches facing the beam, with planters
		local bu, bv = 11, 6
		local f = b:facedir(m, 1, 0.55)
		put(P, m, bu, 1, bv, "stairs:stair_junglewood", f)
		put(P, m, bu + 1, 1, bv, "default:dirt_with_grass")
		put(P, m, bu + 1, 2, bv, "default:bush_leaves")
	end
end

local function gate(P, b, m, g)
	local GU = g.GU
	local top = 23
	for _, uu in ipairs({GU, GU + 1}) do
		for _, vv in ipairs({-15, -14, 14, 15}) do
			for h = 1, top do
				local glow = abs(vv) == 14 and h >= 2 and h <= 8
				local name = glow and MN .. "neon_cyan" or (h <= 2 and "default:stonebrick" or MN .. "panel")
				put(P, m, uu, h, vv, name)
			end
		end
		for vv = -13, 13 do
			for h = 9, top do put(P, m, uu, h, vv, MN .. "panel") end
		end
		for vv = -15, 15 do
			put(P, m, uu, 9, vv, MN .. "neon_magenta")
			put(P, m, uu, top, vv, MN .. "neon_magenta")
		end
	end
	-- stone plinths with depth around the pillar feet
	for _, s in ipairs({-1, 1}) do
		for vv = 13, 16 do
			for _, uu in ipairs({GU - 1, GU + 2}) do
				put(P, m, uu, 1, s * vv, "default:stonebrick")
				b:stair(m, uu, 2, s * vv, "stonebrick", uu == GU - 1 and 1 or -1, 0)
			end
		end
		-- planters on top of the pillars, overgrown
		for uu = GU, GU + 1 do for vv = 14, 15 do
			put(P, m, uu, top + 1, s * vv, "default:dirt_with_grass")
			put(P, m, uu, top + 2, s * vv, "default:leaves")
		end end
		put(P, m, GU + 1, top + 3, s * 15, "default:leaves")
		put(P, m, GU, top + 3, s * 14, MN .. "solar_lantern")
		-- lantern posts at the pillar bases
		b:lantern_post(m, GU - 1, s * 12, 2)
	end
	-- glow vines hanging from the billboard
	for vv = -12, 12, 3 do
		local len = 1 + (abs(vv) * 7) % 3
		for k = 1, len do put(P, m, GU, 9 - k, vv, MN .. "glow_vine") end
	end
	-- lettering: outer face (u = GU+1) read from outside (its right is +v),
	-- inner face (u = GU) read from inside (its right is -v)
	local function line(str, top_h, name, font)
		local w = B.text_width(str, font)
		local left = -floor(w / 2)
		b:text(m, GU + 1, left, top_h, str, name, 0, 1, font)
		b:text(m, GU, -left, top_h, str, name, 0, -1, font)
	end
	line("SPAWN", 19, MN .. "neon_cyan", B.FONT57)
end

local function lamp_cyber(P, m, u, v)
	for h = 1, 4 do if P.get(m[1] * u + m[2] * v, h, m[3] * u + m[4] * v) ~= "air" then return end end
	for h = 1, 3 do put(P, m, u, h, v, MN .. "lamp_pole") end
	put(P, m, u, 4, v, MN .. "lamp_head")
end

local function skeleton(P, b, g)
	local R, RR = g.R, g.RR
	plaza(P, b, g)
	for _, m in ipairs(ROT4) do gate(P, b, m, g) end

	local wall_top = B.pick("walls:cobble", "default:cobble")
	for _, m in ipairs(SYM8) do
		-- hedges and warm lantern posts along the avenues
		for u = g.PL + 2, R - 4 do
			local r = sqrt(u * u + 25)
			if abs(r - RR) > 5 and not (u >= g.GU - 2 and u <= g.GU + 2) then
				local x, z = m[1] * u + m[2] * 5, m[3] * u + m[4] * 5
				if P.get(x, 0, z) == GRASS and P.get(x, 1, z) == "air" then
					if u % 8 == 4 then
						for h = 1, 3 do P.set(x, h, z, "default:fence_junglewood") end
						P.set(x, 4, z, MN .. "solar_lantern")
					elseif u % 8 ~= 3 and u % 8 ~= 5 then
						P.set(x, 1, z, "default:bush_leaves")
					end
				end
			end
		end
		-- cyber lamps along the ring road
		for _, deg in ipairs({7.5, 22.5, 37.5}) do
			local a = deg * pi / 180
			for _, rr in ipairs({RR - 5, RR + 5}) do
				lamp_cyber(P, m, round(rr * math.cos(a)), round(rr * math.sin(a)))
			end
		end
		-- border wall with lanterns (gaps for avenues and diagonal roads)
		for v = 0, R do
			local d = (R - v) / sqrt(2)
			if v >= 5 and d > 3.4 then
				put(P, m, R, 1, v, "default:stonebrick")
				put(P, m, R, 2, v, wall_top)
				if v % 8 == 0 then put(P, m, R, 3, v, MN .. "solar_lantern") end
				-- planter strip inside the wall
				if v % 4 ~= 0 and P.get(m[1] * (R - 1) + m[2] * v, 1, m[3] * (R - 1) + m[4] * v) == "air" then
					put(P, m, R - 1, 0, v, GRASS)
					put(P, m, R - 1, 1, v, (v % 4 == 2) and "default:bush_leaves" or B.pick("flowers:rose", "air"))
				end
			elseif v >= 5 and d > 2.6 then
				put(P, m, R, 1, v, "default:stonebrick")
				put(P, m, R, 2, v, MN .. "solar_lantern")
			end
		end
	end
end

------------------------------------------------------------------------------
-- flora scatter on free grass
------------------------------------------------------------------------------
local function scatter(P, b, g)
	local R = g.R
	local grass = {}
	for i = 1, 5 do grass[i] = "default:grass_" .. i end
	local fl = {}
	for _, n in ipairs({"flowers:rose", "flowers:tulip", "flowers:dandelion_yellow", "flowers:dandelion_white",
			"flowers:geranium", "flowers:viola", "flowers:chrysanthemum_green", "flowers:tulip_black"}) do
		if minetest.registered_nodes[n] then fl[#fl + 1] = n end
	end
	for z = -R, R do for x = -R, R do
		local h = b:ground_xz(x, z)
		if P.get(x, h, z) == GRASS and P.get(x, h + 1, z) == "air" then
			local fi = frame_of(x, z)
			local prof = D.flora[fi] or {grass = 0.3, flowers = 0.05}
			local t = B.hash(x, z, 991)
			local fn = B.noise(x, z, 4, 17 + fi)   -- flowers grow in drifts
			if t < prof.flowers * (0.4 + fn * 1.6) and #fl > 0 then
				local pick = prof.palette and prof.palette[1 + floor(B.hash(x, z, 5) * #prof.palette)]
					or fl[1 + floor(B.hash(x, z, 5) * #fl)]
				if minetest.registered_nodes[pick] then P.set(x, h + 1, z, pick) end
			elseif t < prof.flowers + prof.grass then
				P.set(x, h + 1, z, grass[1 + floor(B.hash(x, z, 6) * 5)])
			end
		end
	end end
end

------------------------------------------------------------------------------
-- infill: jittered grid of trees, bushes and mossy boulders in free gardens
------------------------------------------------------------------------------
local TREES = {
	{"sakura", "aspen"}, {"aspen", "oak"}, {"apple", "oak"}, {"pine", "oak"},
	{"oak", "apple"}, {"sakura", "aspen"}, {"oak", "sakura"}, {"pine", "aspen"},
}
local function infill(P, b, g)
	local R = g.R
	local I = {1, 0, 0, 1}
	local function free(x, z, r, hgt)
		for dx = -r, r do for dz = -r, r do
			if b:ground_xz(x + dx, z + dz) ~= 0 or P.get(x + dx, 0, z + dz) ~= GRASS then return false end
			for h = 1, hgt do
				if P.get(x + dx, h, z + dz) ~= "air" then return false end
			end
		end end
		return true
	end
	local step = 4
	for gx = -R, R, step do for gz = -R, R, step do
		local x = gx + floor(B.hash(gx, gz, 71) * step)
		local z = gz + floor(B.hash(gx, gz, 72) * step)
		if L.room(g, x, z) >= 2.5 then
			local fi = frame_of(x, z)
			local t = B.hash(x, z, 73)
			local seed = 9000 + x * 131 + z
			if t < 0.5 and free(x, z, 1, 7) then
				local kinds = TREES[fi]
				b:tree(I, x, z, kinds[1 + floor(B.hash(x, z, 74) * #kinds)], seed, 0.85 + B.hash(x, z, 75) * 0.35)
			elseif t < 0.8 and free(x, z, 1, 3) then
				local leaves = B.hash(x, z, 76) < 0.3 and "default:blueberry_bush_leaves_with_berries" or nil
				b:bush(I, x, z, leaves, seed, 1.0 + B.hash(x, z, 77) * 0.6)
			elseif free(x, z, 2, 4) then
				b:mound(I, x, z, 1.4, 2, seed)
				if B.hash(x, z, 78) < 0.5 then
					b:put_if_air(I, x, b:ground_xz(x, z) + 1, z, "default:bush_leaves")
				end
			end
		end
	end end
end

------------------------------------------------------------------------------
function L.build_structures(P, g)
	local b = B.new(P, g)
	b.region_fn = function(x, z) return L.room(g, x, z) end
	D.build(b, g, SYM8)
	infill(P, b, g)
	skeleton(P, b, g)
	scatter(P, b, g)
end

-- light beam footprint: returns "core", "halo" or nil
function L.beam_at(x, z)
	if abs(x) <= 1 and abs(z) <= 1 then return "core" end
	if x * x + z * z <= 6.8 then return "halo" end
end

return L
