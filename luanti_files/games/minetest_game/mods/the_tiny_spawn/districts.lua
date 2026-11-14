-- The 8 hand-styled districts between the roads.
-- Every district works in its own local frame: u = distance along the nearest
-- avenue, v = distance away from it (towards the diagonal), u >= v >= 0.
-- Inner part (inside the ring road) is centred around (28, 14),
-- outer part (corner zone outside the ring) around (50, 30)  (for R = 60).
local MN = "the_tiny_spawn:"
local D = {}
local floor, abs, sqrt, max, min, pi = math.floor, math.abs, math.sqrt, math.max, math.min, math.pi
local function round(v) return floor(v + 0.5) end

local F = {}   -- district builders, F[i](b, m, S) ; S(n) scales a position

------------------------------------------------------------------------------
-- 1. ENE  -  Night Bazaar  +  Green Spire
------------------------------------------------------------------------------
local AWNINGS = {{"wool:red", "wool:white"}, {"wool:cyan", "wool:white"}, {"wool:magenta", "wool:white"},
	{"wool:yellow", "wool:white"}, {"wool:blue", "wool:white"}, {"wool:green", "wool:white"}}

local function stall(b, m, u, v, fu, fv, colors, goods)
	-- 3 wide (across), 2 deep; front faces direction (fu, fv)
	local su, sv = -fv, fu
	for a = -1, 1 do
		for dpt = 0, 1 do
			local cu, cv = u + su * a - fu * dpt, v + sv * a - fv * dpt
			b:floor(m, cu, cv, "default:junglewood")
			if abs(a) == 1 then
				for h = 1, 3 do b:put(m, cu, h, cv, "default:fence_junglewood") end
			elseif dpt == 0 then
				b:slab(m, cu, 1, cv, "junglewood", true)
				b:put(m, cu, 2, cv, goods)
			else
				b:put(m, cu, 1, cv, "default:junglewood")
			end
		end
		-- striped awning, one node overhang to the front
		for dpt = -1, 1 do
			local cu, cv = u + su * a - fu * dpt, v + sv * a - fv * dpt
			b:put(m, cu, dpt == -1 and 3 or 4, cv, colors[(a + 2) % 2 + 1])
		end
	end
	b:put(m, u + su, 3, v + sv, MN .. "solar_lantern")
end

F[1] = function(b, m, S)
	local cu, cv = S(28), S(14)
	-- irregular cobbled market square
	for du = -8, 8 do for dv = -8, 8 do
		local u, v = cu + du, cv + dv
		local d = sqrt(du * du + dv * dv)
		if d < 6.8 + b.noise(u, v, 2.5, 41) * 1.6 and b:room(m, u, v) > 0.5 then
			b:floor(m, u, v, b.PAVE, 42)
		end
	end end
	-- central sakura with a ring bench
	b:tree(m, cu, cv, "sakura", 101, 1.1)
	for _, o in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}, {2, 1}, {-2, -1}, {1, -2}, {-1, 2}}) do
		b:put_if_air(m, cu + o[1], 1, cv + o[2], "stairs:stair_junglewood", b:facedir(m, -o[1], -o[2]))
	end
	-- 6 stalls on a circle, all facing the tree
	local goods = {"default:apple", "flowers:dandelion_yellow", "flowers:rose", "default:apple",
		"flowers:tulip", "flowers:viola"}
	for k = 0, 5 do
		local a = (k * 60 + 15) * pi / 180
		local u, v = cu + round(5.4 * math.cos(a)), cv + round(5.4 * math.sin(a))
		local fu, fv = cu - u, cv - v
		if abs(fu) >= abs(fv) then fu, fv = (fu > 0 and 1 or -1), 0 else fu, fv = 0, (fv > 0 and 1 or -1) end
		if b:room(m, u, v) > 1.5 then stall(b, m, u, v, fu, fv, AWNINGS[k + 1], goods[k + 1]) end
	end
	-- holo info totem and crates
	local tu, tv = cu + 7, cv - 4
	for h = 1, 3 do b:put(m, tu, h, tv, "default:fence_junglewood") end
	b:put(m, tu, 4, tv, MN .. "holo_screen")
	b:put(m, tu, 5, tv, MN .. "holo_screen")
	b:put(m, tu, 6, tv, MN .. "neon_magenta")
	for _, c in ipairs({{-6, 3}, {-6, 4}, {-5, 4}}) do b:put(m, cu + c[1], 1, cv + c[2], "default:junglewood") end
	b:put(m, cu - 6, 2, cv + 4, "default:wood")
	for _, p in ipairs({{-3, -6}, {6, 3}, {-7, -1}}) do
		if b:room(m, cu + p[1], cv + p[2]) > 0.5 then b:lantern_post(m, cu + p[1], cv + p[2], 3) end
	end

	-- outer: Green Spire - terraced solarpunk tower with gardens on every level
	local ou, ov = S(50), S(31)
	for du = -5, 5 do for dv = -5, 5 do
		b:floor(m, ou + du, ov + dv, (abs(du) == 5 or abs(dv) == 5) and MN .. "neon_purple" or "default:stonebrick")
	end end
	local levels = {{3, 1, 8}, {2, 10, 17}, {1, 19, 26}}
	for li, L in ipairs(levels) do
		local hw, h1, h2 = L[1], L[2], L[3]
		for h = h1, h2 do
			for du = -hw, hw do for dv = -hw, hw do
				local eu, ev = abs(du) == hw, abs(dv) == hw
				if eu or ev then
					local name = "default:silver_sandstone_block"
					if eu and ev then name = li == 2 and MN .. "neon_magenta" or MN .. "neon_cyan"
					elseif (h - h1) % 3 ~= 0 then name = "default:glass" end
					b:put(m, ou + du, h, ov + dv, name)
				else
					b:put(m, ou + du, h, ov + dv, "air")
				end
			end end
		end
		-- terrace with planters, hanging vines
		local th = h2 + 1
		for du = -hw - 1, hw + 1 do for dv = -hw - 1, hw + 1 do
			local edge = abs(du) == hw + 1 or abs(dv) == hw + 1
			b:put(m, ou + du, th, ov + dv, edge and "default:dirt_with_grass" or "default:silver_sandstone_brick")
			if edge then
				local hsh = b.hash(ou + du, ov + dv + th, 7)
				b:put(m, ou + du, th + 1, ov + dv, hsh < 0.55 and "default:bush_leaves" or
					(hsh < 0.75 and "flowers:rose" or "default:leaves"))
				if hsh > 0.6 then
					for k = 1, 2 + floor(hsh * 3) do
						b:put_if_air(m, ou + du, th - k, ov + dv, MN .. "glow_vine")
					end
				end
			end
		end end
		b:put(m, ou, th, ov, "default:meselamp")
	end
	-- crown: wind turbine + beacon
	for h = 28, 32 do b:put(m, ou, h, ov, "default:steelblock") end
	for k = 1, 4 do
		b:put(m, ou - 1, 32 + k, ov, "wool:white")
		b:put(m, ou - 1, 32 - k, ov + k, "wool:white")
		b:put(m, ou - 1, 32 - k, ov - k, "wool:white")
	end
	b:put(m, ou - 1, 32, ov, MN .. "neon_cyan")
	b:put(m, ou, 33, ov, MN .. "beacon_red")
	-- door + path to the ring road
	for h = 1, 2 do b:put(m, ou - 3, h, ov, "air") end
	for u = ou - 9, ou - 4 do b:floor(m, u, ov, b.PAVE_WARM, 43) end
	b:tree(m, ou - 5, ov + 7, "apple", 102)
	b:tree(m, ou + 3, ov + 9, "aspen", 103)
	b:bush(m, ou - 6, ov - 5, "default:blueberry_bush_leaves_with_berries", 104)
end

------------------------------------------------------------------------------
-- 2. ESE  -  Mill Canal  +  Neon Café
------------------------------------------------------------------------------
F[2] = function(b, m, S)
	-- curving stream from a spring pool to a lotus basin
	local pts = {{S(35), S(12)}, {S(31), S(14)}, {S(27), S(14)}, {S(23), S(12)}, {S(19), S(9)}}
	local water = {}
	for i = 1, #pts - 1 do
		local a, c = pts[i], pts[i + 1]
		for t = 0, 1, 0.1 do
			local u, v = a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t
			for du = -2, 2 do for dv = -2, 2 do
				if du * du + dv * dv <= 2.3 then water[round(u + du) * 1000 + round(v + dv)] = true end
			end end
		end
	end
	for key in pairs(water) do
		local u = floor((key + 500) / 1000); local v = key - u * 1000
		if b:room(m, u, v) >= 1 then
			b:put(m, u, -2, v, "default:sand")
			b:put(m, u, -1, v, "default:water_source")
			b:put(m, u, 0, v, "default:water_source")
			b:set_ground(m, u, v, -1)
			for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local k2 = (u + o[1]) * 1000 + v + o[2]
				if not water[k2] and b:get(m, u + o[1], 0, v + o[2]) == "default:dirt_with_grass" then
					b:floor(m, u + o[1], v + o[2], {{"default:stonebrick", 0.55}, {"default:mossycobble", 1}}, 21)
				end
			end
		end
	end
	b:pond(m, S(18), S(8), 2.6, 22)
	for _, p in ipairs({{S(18), S(8)}, {S(19), S(9)}, {S(35), S(12)}}) do b:put(m, p[1], 1, p[2], "flowers:waterlily", 0) end
	-- arched stone bridge over the stream
	local bu = S(27)
	for v = S(12), S(16) do
		local mid = abs(v - S(14))
		b:put(m, bu, mid <= 1 and 1 or 0, v, "default:stonebrick")
		if mid == 2 then b:stair(m, bu, 1, v, "stonebrick", 0, v < S(14) and 1 or -1) end
		if mid <= 1 then b:put(m, bu, 2, v, "stairs:slab_stonebrick") end
		b:put(m, bu - 1, (mid <= 1) and 2 or 1, v, b.pick("walls:cobble", "default:fence_wood"))
		b:put(m, bu + 1, (mid <= 1) and 2 or 1, v, b.pick("walls:cobble", "default:fence_wood"))
	end
	-- mill house with a water wheel
	local hu, hv = S(26), S(18)
	b:house(m, hu, hv, 6, 5, 5, {door = "+u", roof = "wood", wall = "default:wood", frame = "default:tree"})
	local wu, wh, wv = hu + 2, 3, hv - 1
	for du = -3, 3 do for dh = -3, 3 do
		local d = sqrt(du * du + dh * dh)
		if (d > 2.4 and d < 3.5) or (du == 0 or dh == 0 or abs(du) == abs(dh)) and d < 3.5 then
			if wh + dh >= 0 then b:put(m, wu + du, wh + dh, wv, d > 2.4 and "default:junglewood" or "default:tree") end
		end
	end end
	b:put(m, wu, wh, wv, MN .. "neon_cyan")
	b:tree(m, S(34), S(20), "aspen", 201)
	b:tree(m, S(17), S(12), "oak", 202, 0.9)
	b:lantern_post(m, S(30), S(10), 3)
	b:lantern_post(m, S(22), S(16), 3)

	-- outer: café with a terrace, parasols and a neon sign
	local cu, cv = S(47), S(29)
	b:house(m, cu, cv, 8, 8, 8, {door = "-u", roof = "obsidianbrick", wall = "default:silver_sandstone_block",
		frame = "default:junglewood", glass = "default:obsidian_glass"})
	-- neon CAFE sign on the facade (read from the terrace: right = -v ... text runs +v from the left)
	b:text(m, cu - 1, cv + 1, 8, "CAFE", MN .. "neon_magenta", 0, 1)
	for v = cv - 1, cv + 9 do for u = S(41), cu - 1 do
		if b:room(m, u, v) > 0.5 then b:floor(m, u, v, b.PAVE_WARM, 23) end
	end end
	local colors = {{"wool:red", "wool:white"}, {"wool:cyan", "wool:white"}, {"wool:yellow", "wool:white"}}
	for i, t in ipairs({{S(43), cv + 1}, {S(43), cv + 5}, {S(45), cv + 8}}) do
		local tu, tv = t[1], t[2]
		if b:room(m, tu, tv) > 1 then
			b:put(m, tu, 1, tv, "default:fence_junglewood")
			b:slab(m, tu, 2, tv, "junglewood")
			for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				b:put_if_air(m, tu + o[1], 1, tv + o[2], "stairs:stair_wood", b:facedir(m, o[1], o[2]))
			end
			for h = 3, 3 do b:put(m, tu, h, tv, "default:fence_junglewood") end
			for du = -1, 1 do for dv = -1, 1 do
				b:put(m, tu + du, 4, tv + dv, colors[i][(du + dv + 2) % 2 + 1])
			end end
		end
	end
	b:lantern_post(m, S(41), cv - 1, 3)
	b:lantern_post(m, S(41), cv + 9, 3)
	b:tree(m, cu + 4, cv + 12, "sakura", 203)
end

------------------------------------------------------------------------------
-- 3. NNW  -  Solar Windmill & fields  +  Workshop barn
------------------------------------------------------------------------------
F[3] = function(b, m, S)
	local wheat = b.pick("farming:wheat_8", "default:grass_5")
	local cotton = b.pick("farming:cotton_8", "default:dry_grass_5")
	local soil = b.pick("farming:soil_wet", "default:dirt")
	local function field(u1, u2, v1, v2, crop)
		for u = u1, u2 do for v = v1, v2 do
			if b:room(m, u, v) > 1 then
				local edge = u == u1 or u == u2 or v == v1 or v == v2
				if edge then
					b:put(m, u, 1, v, "default:fence_wood")
				elseif (v - v1) % 4 == 0 then
					b:floor(m, u, v, "default:water_source")
					b:set_ground(m, u, v, -1)
				else
					b:floor(m, u, v, soil)
					b:put(m, u, 1, v, crop)
				end
			end
		end end
		b:put(m, u1, 1, floor((v1 + v2) / 2), "air")
	end
	field(S(16), S(25), S(7), S(13), wheat)
	field(S(19), S(26), S(16), S(21), cotton)
	-- windmill: stone base, timber tower, dark cap, sails facing the centre
	local wu, wv = S(31), S(14)
	for h = 1, 15 do
		local r = h <= 5 and 3.2 or (h <= 12 and 2.5 or 2.5 - (h - 12) * 0.8)
		for du = -4, 4 do for dv = -4, 4 do
			local d = sqrt(du * du + dv * dv)
			if d <= r + 0.3 then
				local shell = d > r - 0.9
				local name = "air"
				if shell then
					if h <= 5 then name = b.mix(b.PAVE, du, dv + h, 51)
					elseif h <= 12 then name = (h % 4 == 0 and abs(du) + abs(dv) <= 2) and "default:glass"
						or ((du == 0 or dv == 0) and "default:junglewood" or "default:wood")
					else name = "default:obsidianbrick" end
				end
				b:put(m, wu + du, h, wv + dv, name)
			end
		end end
	end
	b:put(m, wu, 16, wv, MN .. "beacon_red")
	for h = 1, 2 do b:put(m, wu - 3, h, wv, "air") end
	-- solar panels skirt around the base roof line
	for _, o in ipairs({{3, 2}, {3, -2}, {2, 3}, {-2, 3}, {2, -3}}) do b:put(m, wu + o[1], 6, wv + o[2], MN .. "solar_panel") end
	-- sails (X shape) in the plane u = wu - 3
	local su, hub = wu - 3, 11
	b:put(m, su + 1, hub, wv, "default:junglewood")
	b:put(m, su, hub, wv, MN .. "neon_cyan")
	for _, dirn in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
		for k = 1, 8 do
			local v, h = wv + dirn[1] * k, hub + dirn[2] * k
			if h >= 2 then
				b:put(m, su, h, v, k == 8 and MN .. "neon_magenta" or "default:junglewood")
				if k >= 2 and k <= 7 then
					b:put(m, su, h + dirn[1] * 0, v - dirn[1], "wool:white")
					b:put(m, su, h - dirn[2], v, "wool:white")
				end
			end
		end
	end
	local straw = b.pick("farming:straw", "default:dry_grass_1")
	for _, p in ipairs({{S(35), S(9)}, {S(36), S(9)}, {S(35), S(10)}}) do
		if straw ~= "default:dry_grass_1" then b:put(m, p[1], 1, p[2], straw) end
	end
	b:put(m, S(35), 2, S(9), straw ~= "default:dry_grass_1" and straw or "air")
	b:lantern_post(m, S(28), S(9), 3)
	b:tree(m, S(16), S(10) + 5, "apple", 301)

	-- outer: workshop barn with solar canopy
	local bu, bv = S(45), S(25)
	b:house(m, bu, bv, 10, 7, 6, {door = "-u", roof = "obsidianbrick", wall = "default:acacia_wood",
		frame = "default:pine_wood", post = "default:pine_tree", base = "default:desert_stonebrick"})
	-- solar canopy beside the barn
	local cu, cv = S(46), S(35)
	for du = 0, 7 do for dv = 0, 3 do
		if b:room(m, cu + du, cv + dv) > 0 then
			if (du == 0 or du == 7) and (dv == 0 or dv == 3) then
				for h = 1, 3 do b:put(m, cu + du, h, cv + dv, "default:steelblock") end
			end
			b:put(m, cu + du, 4, cv + dv, MN .. "solar_panel")
		end
	end end
	b:put(m, cu + 3, 1, cv + 1, "default:steelblock")
	b:put(m, cu + 4, 1, cv + 1, MN .. "neon_cyan")
	for _, c in ipairs({{-2, 0}, {-2, 1}, {-1, 0}}) do b:put(m, bu + c[1], 1, bv + 7 + c[2], "default:wood") end
	b:tree(m, S(42), S(33) + 4, "oak", 302)
	b:bush(m, S(53), S(23), nil, 303)
end

------------------------------------------------------------------------------
-- 4. NNE  -  Waterfall Cliffs & pond  +  Greenhouse dome
------------------------------------------------------------------------------
F[4] = function(b, m, S)
	local hu, hv = S(30), S(19)
	local pu, pv = S(22), S(11)
	local dirx, dirz = pu - hu, pv - hv
	local hmap = b:mound(m, hu, hv, 7.5, 9, 401, {cliff = {dirx, dirz}})
	b:pond(m, pu, pv, 3.6, 402)
	-- waterfall: walk from the hill top towards the pond until the cliff edge
	local len = sqrt(dirx * dirx + dirz * dirz)
	local sx, sz = dirx / len, dirz / len
	local top = b:ground(m, hu, hv)
	local edge_u, edge_v, edge_h
	for k = 0, 10 do
		local u, v = round(hu + sx * k), round(hv + sz * k)
		local g = b:ground(m, u, v)
		if g < top - 3 then break end
		edge_u, edge_v, edge_h = u, v, g
	end
	if edge_u and edge_h >= 3 then
		b:put(m, edge_u, edge_h, edge_v, "default:water_source")
		for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			b:put_if_air(m, edge_u + o[1], edge_h + 1, edge_v + o[2], "default:mossycobble")
		end
		local fu, fv = round(edge_u + sx), round(edge_v + sz)
		if fu == edge_u and fv == edge_v then fu = fu + 1 end
		b:put(m, fu, edge_h + 1, fv, "air")
		local g = b:ground(m, fu, fv)
		for h = edge_h, max(g + 1, 1), -1 do b:put(m, fu, h, fv, "default:water_flowing", 15) end
		-- splash pool at the foot
		for du = -1, 1 do for dv = -1, 1 do
			if b:get(m, fu + du, 0, fv + dv) ~= "air" then
				b:put(m, fu + du, 0, fv + dv, "default:water_source")
				b:put(m, fu + du, -1, fv + dv, "default:water_source")
				b:put(m, fu + du, -2, fv + dv, "default:sand")
			end
		end end
	end
	-- trees and a lookout on the hill
	local rng = PcgRandom(403)
	b:tree(m, hu + 2, hv + 2, "pine", 404)
	b:tree(m, hu - 1, hv + 4, "pine", 405, 0.8)
	b:tree(m, hu + 4, hv - 2, "oak", 406)
	b:stone_lantern(m, hu - 2, hv - 1)
	b:vines(m, hu, hv, 8, 2, 14, rng, 5)
	-- glow vines down the cliff face
	for du = -8, 8 do for dv = -8, 8 do
		local u, v = hu + du, hv + dv
		local g = b:ground(m, u, v)
		if g == 0 and (du * dirx + dv * dirz) > 0 then
			for _, o in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local gn = b:ground(m, u + o[1], v + o[2])
				if gn >= 4 and rng:next(0, 100) < 30 then
					for h = gn - 1, gn - rng:next(1, 3), -1 do b:put_if_air(m, u, h, v, MN .. "glow_vine") end
				end
			end
		end
	end end
	for _, p in ipairs({{pu - 1, pv + 1}, {pu + 1, pv - 2}}) do b:put(m, p[1], 1, p[2], "flowers:waterlily", 0) end
	for _, p in ipairs({{pu - 3, pv}, {pu - 3, pv + 1}, {pu, pv - 3}}) do
		if b:get(m, p[1], 0, p[2]) ~= "default:water_source" then
			b:put(m, p[1], 1, p[2], "default:papyrus"); b:put(m, p[1], 2, p[2], "default:papyrus")
		end
	end
	b:lantern_post(m, pu + 4, pv - 3, 3)

	-- outer: greenhouse dome
	local gu, gv = S(50), S(32)
	for du = -7, 7 do for dv = -7, 7 do
		local d = sqrt(du * du + dv * dv)
		if d <= 7.2 then b:floor(m, gu + du, gv + dv, d > 6.2 and "default:stonebrick" or "default:dirt_with_grass") end
	end end
	b:dome(m, gu, gv, 1, 6, "default:glass", "default:junglewood")
	for _, o in ipairs({{-6, 0}, {-6, 1}, {-6, -1}}) do for h = 1, 2 do b:put(m, gu + o[1], h, gv + o[2], "air") end end
	b:put(m, gu, 1, gv, "default:meselamp")
	b:tree(m, gu + 2, gv + 1, "jungle", 407, 0.7)
	for du = -4, 4 do for dv = -4, 4 do
		local d = sqrt(du * du + dv * dv)
		if d > 1.5 and d < 4.5 and b:get(m, gu + du, 1, gv + dv) == "air" and b.hash(gu + du, gv + dv, 9) < 0.55 then
			local pl = {"flowers:rose", "flowers:tulip", "flowers:viola", "default:fern_1", "default:junglegrass"}
			b:put(m, gu + du, 1, gv + dv, b.pick(pl[1 + floor(b.hash(du, dv, 4) * #pl)], "default:grass_3"))
		end
	end end
	for u = gu - 11, gu - 7 do b:floor(m, u, gv, b.PAVE_WARM, 44) end
	b:lantern_post(m, gu - 8, gv + 2, 3)
	b:lantern_post(m, gu - 8, gv - 2, 3)
	b:tree(m, gu + 1, gv + 10, "apple", 408)
end

------------------------------------------------------------------------------
-- 5. WSW  -  Tree of Light  +  Observatory
------------------------------------------------------------------------------
F[5] = function(b, m, S)
	local cu, cv = S(28), S(15)
	local rng = PcgRandom(501)
	-- mossy stone ring path and ring bench
	for du = -8, 8 do for dv = -8, 8 do
		local d = sqrt(du * du + dv * dv)
		if d > 6 and d < 7.2 and b:room(m, cu + du, cv + dv) > 0 then
			b:floor(m, cu + du, cv + dv, {{"default:mossycobble", 0.5}, {"default:stonebrick", 1}}, 52)
		end
	end end
	-- trunk 3x3 with root flares
	for du = -1, 1 do for dv = -1, 1 do
		for h = 1, 13 do
			if not (abs(du) == 1 and abs(dv) == 1 and h > 9) then b:put(m, cu + du, h, cv + dv, "default:jungletree") end
		end
	end end
	for k = 0, 7 do
		local a = k * pi / 4 + 0.3
		local len = 3 + rng:next(0, 2)
		for s = 2, len do
			local u, v = cu + round(math.cos(a) * s), cv + round(math.sin(a) * s)
			b:put(m, u, 1, v, "default:jungletree")
			if s == 2 then b:put(m, u, 2, v, "default:jungletree") end
		end
	end
	-- branches with canopy blobs (green + glowing pink)
	local tips = {}
	for k = 0, 5 do
		local a = k * pi / 3 + rng:next(0, 40) / 100
		local len = 5 + rng:next(0, 2)
		local u, v, h = cu, cv, 10 + (k % 3)
		for s = 1, len do
			u, v = cu + round(math.cos(a) * s), cv + round(math.sin(a) * s)
			if s % 2 == 0 then h = h + 1 end
			b:put(m, u, h, v, "default:jungletree")
		end
		tips[#tips + 1] = {u, v, h}
	end
	local function canopy(u, v, h, r)
		for du = -4, 4 do for dv = -4, 4 do for dh = -2, 3 do
			local d = sqrt(du * du + dv * dv + dh * dh * 2)
			if d <= r + rng:next(0, 80) / 100 - 0.4 then
				b:put_if_air(m, u + du, h + dh, v + dv, rng:next(0, 100) < 30 and MN .. "neon_leaves" or "default:jungleleaves")
			end
		end end end
	end
	for _, t in ipairs(tips) do canopy(t[1], t[2], t[3] + 1, 3.2) end
	canopy(cu, cv, 15, 4)
	b:vines(m, cu, cv, 10, 4, 19, rng, 16)
	for _, t in ipairs(tips) do
		if b:get(m, t[1], t[3] - 1, t[2]) == "air" then b:put(m, t[1], t[3] - 1, t[2], MN .. "solar_lantern") end
	end
	for k = 0, 15 do
		local a = k * pi / 8
		if k % 4 ~= 0 then
			local u, v = cu + round(math.cos(a) * 4.6), cv + round(math.sin(a) * 4.6)
			b:put_if_air(m, u, 1, v, "stairs:stair_junglewood", b:facedir(m, u - cu, v - cv))
		end
	end

	-- outer: observatory
	local ou, ov = S(50), S(31)
	for du = -5, 5 do for dv = -5, 5 do
		local d = sqrt(du * du + dv * dv)
		if d <= 5.3 then
			b:floor(m, ou + du, ov + dv, d > 4.5 and MN .. "neon_cyan" or "default:silver_sandstone_brick")
			if d > 3.5 and d <= 4.5 then
				for h = 1, 7 do
					local name = (h == 4 or h == 5) and (abs(du) + abs(dv)) % 3 == 0 and "default:glass"
						or b.mix(b.PAVE_WARM, du * 3 + h, dv, 53)
					b:put(m, ou + du, h, ov + dv, h == 7 and MN .. "neon_purple" or name)
				end
			end
		end
	end end
	b:dome(m, ou, ov, 8, 4, "default:obsidian_glass", "default:steelblock")
	for k = 0, 5 do b:put(m, ou + k, 10 + k, ov, k == 5 and "default:goldblock" or "default:tinblock") end
	for h = 1, 2 do b:put(m, ou - 4, h, ov, "air") end
	b:put(m, ou, 1, ov, "default:meselamp")
	for u = ou - 10, ou - 6 do b:floor(m, u, ov, b.PAVE_WARM, 54) end
	b:stone_lantern(m, ou - 7, ov + 3)
	b:stone_lantern(m, ou - 7, ov - 3)
	b:tree(m, ou + 2, ov + 9, "aspen", 502)
	b:tree(m, ou - 4, ov + 9, "aspen", 503, 0.8)
end

------------------------------------------------------------------------------
-- 6. WNW  -  Lotus Pond & pavilion  +  Sakura grove
------------------------------------------------------------------------------
F[6] = function(b, m, S)
	local cu, cv = S(28), S(14)
	b:pond(m, cu, cv, 6.5, 601)
	-- island with a pagoda pavilion
	for du = -2, 2 do for dv = -2, 2 do
		if du * du + dv * dv <= 5 then
			b:put(m, cu + du, -1, cv + dv, "default:dirt")
			b:put(m, cu + du, 0, cv + dv, (du * du + dv * dv <= 2) and "default:junglewood" or "default:dirt_with_grass")
			b:set_ground(m, cu + du, cv + dv, 0)
		end
	end end
	for _, o in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
		for h = 1, 3 do b:put(m, cu + o[1], h, cv + o[2], "default:tree") end
	end
	for lvl = 0, 2 do
		local r = 2 - lvl
		local h = 4 + lvl
		for du = -r - 1, r + 1 do for dv = -r - 1, r + 1 do
			local edge = abs(du) == r + 1 or abs(dv) == r + 1
			if edge then
				local fu = abs(du) >= abs(dv) and (du > 0 and -1 or 1) or 0
				local fv = fu == 0 and (dv > 0 and -1 or 1) or 0
				b:stair(m, cu + du, h, cv + dv, "obsidianbrick", fu, fv)
			else
				b:put(m, cu + du, h, cv + dv, lvl == 2 and MN .. "neon_magenta" or "default:obsidianbrick")
			end
		end end
	end
	b:put(m, cu, 7, cv, MN .. "solar_lantern")
	b:put(m, cu, 3, cv, MN .. "solar_lantern")
	-- wooden pier from the avenue side
	for v = S(6), cv - 2 do
		if b:get(m, cu, 0, v) == "default:water_source" or v >= cv - 3 then
			b:slab(m, cu, 0, v, "junglewood", true)
			b:put(m, cu, -1, v, "default:water_source")
		else
			b:floor(m, cu, v, "default:junglewood")
		end
		if (v - S(6)) % 3 == 0 then
			b:put(m, cu - 1, 1, v, "default:fence_junglewood")
			b:put(m, cu + 1, 1, v, "default:fence_junglewood")
		end
	end
	-- lilies, reeds, stepping stones
	local rng = PcgRandom(602)
	for du = -8, 8 do for dv = -8, 8 do
		local u, v = cu + du, cv + dv
		if b:get(m, u, 0, v) == "default:water_source" and b:get(m, u, 1, v) == "air" then
			local t = rng:next(0, 100)
			if t < 12 then b:put(m, u, 1, v, "flowers:waterlily", rng:next(0, 3))
			elseif t < 14 then b:put(m, u, 1, v, MN .. "crystal_cyan") end
		elseif b:get(m, u, 0, v) == "default:sand" and rng:next(0, 100) < 35 then
			local hgt = rng:next(1, 3)
			for h = 1, hgt do b:put_if_air(m, u, h, v, "default:papyrus") end
		end
	end end
	b:tree(m, cu + 8, cv + 6, "aspen", 603)
	b:lantern_post(m, cu + 3, S(6) + 1, 3)
	b:lantern_post(m, cu - 3, S(6) + 1, 3)

	-- outer: sakura grove around a stone lantern circle
	local gu, gv = S(49), S(31)
	for i, p in ipairs({{-4, -4}, {4, -5}, {5, 3}, {-1, 6}, {-6, 2}, {2, 10}}) do
		if b:room(m, gu + p[1], gv + p[2]) > 1.5 then b:tree(m, gu + p[1], gv + p[2], "sakura", 610 + i) end
	end
	for du = -2, 2 do for dv = -2, 2 do
		if du * du + dv * dv <= 5 then b:floor(m, gu + du, gv + dv, b.PAVE_WARM, 61) end
	end end
	b:stone_lantern(m, gu, gv)
	for _, o in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}}) do b:bench(m, gu + o[1], gv + o[2], -o[1], -o[2]) end
end

------------------------------------------------------------------------------
-- 7. SSE  -  Holo Amphitheatre  +  Hedge maze
------------------------------------------------------------------------------
F[7] = function(b, m, S)
	local cu, cv = S(23), S(10)
	local au, av = 1, 0.75   -- seats open towards +u/+v
	local an = sqrt(au * au + av * av); au, av = au / an, av / an
	for du = -12, 12 do for dv = -12, 12 do
		local u, v = cu + du, cv + dv
		local d = sqrt(du * du + dv * dv)
		local dot = d > 0 and (du * au + dv * av) / d or 0
		if b:room(m, u, v) > 0.5 then
			if d <= 3.5 then
				b:put(m, u, 1, v, d > 2.7 and MN .. "neon_cyan" or "default:silver_sandstone_block")
				b:set_ground(m, u, v, 1)
			elseif dot > -0.15 and d >= 5 and d < 11 then
				local row = floor((d - 5) / 1.5) + 1
				for h = 0, row - 1 do b:put(m, u, h, v, "default:stonebrick") end
				local aisle = abs(dot - 0.55) < 0.06
				if aisle then
					b:put(m, u, row, v, "default:stone_block")
				else
					b:stair(m, u, row, v, "silver_sandstone_brick", round(du / d), round(dv / d))
				end
				b:set_ground(m, u, v, row)
			end
		end
	end end
	-- holographic backdrop behind the stage
	local bu, bv = cu - round(au * 4.5), cv - round(av * 4.5)
	local su, sv = -av, au
	for k = -3, 3 do
		local u, v = bu + round(su * k), bv + round(sv * k)
		for h = 1, 6 do
			b:put(m, u, h, v, (abs(k) == 3 or h == 6) and MN .. "neon_magenta" or MN .. "holo_screen")
		end
	end
	b:lantern_post(m, cu + 5, cv - 4, 3)
	b:lantern_post(m, cu - 4, cv + 5, 3)
	b:tree(m, S(34), S(22), "oak", 701)
	b:tree(m, S(36), S(10), "sakura", 702)

	-- outer: hedge maze with a crystal fountain in the middle
	local mu, mv = S(44), S(25)
	local N = 13
	local cells = {}
	local rng = PcgRandom(703)
	local function key(i, j) return i * 100 + j end
	local stack, seen = {{1, 1}}, {[key(1, 1)] = true}
	local open = {}
	while #stack > 0 do
		local c = stack[#stack]
		local opts = {}
		for _, o in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}}) do
			local ni, nj = c[1] + o[1], c[2] + o[2]
			if ni >= 1 and ni < N - 1 and nj >= 1 and nj < N - 1 and not seen[key(ni, nj)] then opts[#opts + 1] = {ni, nj, o} end
		end
		if #opts == 0 then
			stack[#stack] = nil
		else
			local n = opts[rng:next(1, #opts)]
			seen[key(n[1], n[2])] = true
			open[key(c[1] + n[3][1] / 2, c[2] + n[3][2] / 2)] = true
			stack[#stack + 1] = {n[1], n[2]}
		end
	end
	for i = 0, N - 1 do for j = 0, N - 1 do
		local u, v = mu + i, mv + j
		local passage = (i % 2 == 1 and j % 2 == 1) or open[key(i, j)]
		local centre = abs(i - 6) <= 1 and abs(j - 6) <= 1
		local entrance = (i == 0 and j == 1) or (i == N - 1 and j == N - 2)
		if b:room(m, u, v) > -0.5 then
			if centre then
				b:floor(m, u, v, "default:silver_sandstone_brick")
			elseif passage or entrance then
				b:floor(m, u, v, "default:gravel")
			else
				b:put(m, u, 1, v, "default:bush_leaves")
				b:put(m, u, 2, v, "default:bush_leaves")
			end
		end
	end end
	b:put(m, mu + 6, 1, mv + 6, MN .. "neon_cyan")
	for h = 2, 4 do b:put(m, mu + 6, h, mv + 6, MN .. "holo_column") end
	for _, o in ipairs({{5, 5}, {7, 7}, {5, 7}, {7, 5}}) do b:put(m, mu + o[1], 1, mv + o[2], MN .. "crystal_magenta") end
	b:lantern_post(m, mu - 1, mv, 3)
	b:lantern_post(m, mu - 1, mv + 3, 3)
end

------------------------------------------------------------------------------
-- 8. SSW  -  Crystal Garden & geode  +  Solar farm
------------------------------------------------------------------------------
F[8] = function(b, m, S)
	local cu, cv = S(28), S(14)
	local rng = PcgRandom(801)
	-- half buried geode dome with an opening, lined with crystals
	for du = -6, 6 do for dv = -6, 6 do for dh = 0, 6 do
		local d = sqrt(du * du + dv * dv + dh * dh)
		local u, v = cu + du, cv + dv
		if d < 5.5 and b:room(m, u, v) > 0 then
			if d >= 4.5 then
				local hole = (du < -2 and abs(dv) <= 1 and dh <= 2) or (dh >= 4 and abs(du) + abs(dv) <= 2)
				if not hole then
					b:put(m, u, dh, v, d > 5 and "default:obsidian" or b.mix({{"default:obsidianbrick", 0.5},
						{MN .. "neon_purple", 0.62}, {"default:obsidian", 1}}, u + dh * 5, v, 81, 1.3))
				end
			elseif dh >= 1 then
				b:put(m, u, dh, v, "air")
			end
		end
	end end end
	for du = -4, 4 do for dv = -4, 4 do
		local u, v = cu + du, cv + dv
		if du * du + dv * dv <= 14 then
			b:floor(m, u, v, (du * du + dv * dv <= 2) and "default:mese" or "default:obsidian")
			if b:get(m, u, 1, v) == "air" and rng:next(0, 100) < 45 and du * du + dv * dv > 2 then
				b:put(m, u, 1, v, rng:next(0, 1) == 0 and MN .. "crystal_cyan" or MN .. "crystal_magenta")
			end
		end
	end end
	b:put(m, cu, 1, cv, MN .. "holo_column")
	b:put(m, cu, 2, cv, MN .. "holo_column")
	-- rock outcrops with crystals around the garden
	for i, p in ipairs({{-7, -4}, {7, 6}, {-3, 8}, {8, -3}, {-9, 3}}) do
		local u, v = cu + p[1], cv + p[2]
		if b:room(m, u, v) > 1.5 then
			local hm = b:mound(m, u, v, 1.8, 2 + i % 2, 810 + i)
			local g = b:ground(m, u, v)
			b:put(m, u, g + 1, v, i % 2 == 0 and MN .. "crystal_cyan" or MN .. "crystal_magenta")
			b:put(m, u + 1, b:ground(m, u + 1, v) + 1, v, MN .. "crystal_cyan")
		end
	end
	-- gravel path to the geode entrance
	for u = S(16), cu - 5 do b:floor(m, u, cv, "default:gravel") end
	b:lantern_post(m, cu - 6, cv + 2, 3)
	b:lantern_post(m, cu - 6, cv - 2, 3)
	b:tree(m, S(36), S(20), "pine", 802)

	-- outer: solar farm with a control hut and batteries
	for row = 0, 3 do
		local v = S(26) + row * 3
		for u = S(44), S(55) do
			if b:room(m, u, v) > 0.5 then
				if (u - S(44)) % 3 == 0 then b:put(m, u, 1, v, "default:fence_wood") end
				b:put(m, u, 2, v, MN .. "solar_panel")
				b:floor(m, u, v - 1, "default:gravel")
			end
		end
	end
	local hu, hv = S(50), S(38)
	if b:room(m, hu, hv) > 0 then
		b:house(m, hu, hv, 5, 4, 4, {door = "-u", roof = "steelblock", wall = "default:silver_sandstone_block"})
		b:put(m, hu - 1, 3, hv + 2, MN .. "holo_screen")
	end
	for _, p in ipairs({{S(46), S(38)}, {S(46), S(40)}}) do
		if b:room(m, p[1], p[2]) > 0.5 then
			b:put(m, p[1], 1, p[2], "default:steelblock")
			b:put(m, p[1], 2, p[2], MN .. "neon_cyan")
		end
	end
end

------------------------------------------------------------------------------
-- flora profiles per district frame (used by the scatter pass)
------------------------------------------------------------------------------
D.flora = {
	[1] = {grass = 0.25, flowers = 0.08},
	[2] = {grass = 0.3, flowers = 0.06, palette = {"flowers:geranium", "flowers:viola", "flowers:dandelion_white"}},
	[3] = {grass = 0.32, flowers = 0.1, palette = {"flowers:dandelion_yellow", "flowers:dandelion_white", "flowers:tulip"}},
	[4] = {grass = 0.4, flowers = 0.06, palette = {"flowers:viola", "flowers:geranium", "flowers:chrysanthemum_green"}},
	[5] = {grass = 0.3, flowers = 0.06, palette = {"flowers:mushroom_red", "flowers:viola", "flowers:rose"}},
	[6] = {grass = 0.3, flowers = 0.07, palette = {"flowers:rose", "flowers:tulip", "flowers:dandelion_white"}},
	[7] = {grass = 0.3, flowers = 0.05},
	[8] = {grass = 0.15, flowers = 0.1, palette = {"flowers:viola", "flowers:geranium", "flowers:tulip_black"}},
}

function D.build(b, g, SYM8)
	local s = g.s
	local function S(n) return round(n * s) end
	for i = 1, 8 do
		local ok, err = pcall(F[i], b, SYM8[i], S)
		if not ok then minetest.log("error", "[the_tiny_spawn] district " .. i .. ": " .. tostring(err)) end
	end
end

return D
