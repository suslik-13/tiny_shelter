-- Ruined portal (spec cycle 7): Mineclonia's eight schematics (five small,
-- three giant, 5 % giant) and its processors and numbers: 30 % of the gold
-- blocks gone, netherrack 7 % magma (cold portals: lava turns netherrack),
-- stone bricks weathered (mossy by the setup's mossiness, else cracked),
-- obsidian 15 % crying, nothing non-solid in lava, blackstone in the Nether;
-- a ring of netherrack and magma spread over the ground around, pillars of
-- it under the floor, jungle leaves and vines when overgrown. The setups
-- (placement, air pocket, mossiness) are Mineclonia's per variant; air of
-- the schematic is written only inside the air pocket. One chest with
-- Bedrock's ruined_portal loot. Repaired with obsidian the frame lights as
-- the server's portal: any size on our own Nether, exactly 4×5 with the
-- nether mod. Placed only by admins.
local S = cb_structures.S
local T = cb_structures.templates
local A = cb_structures.piecegen
local VS = cb_structures.village_schem
local RP = { GIANT = 5, RING = 14, }
cb_structures.ruined_portal = RP

local OBSIDIAN, CRYING = cb_core.equiv("obsidian"), A.first("cb_blocks:crying_obsidian", "default:obsidian")
local NETHERRACK = cb_core.equiv("netherrack")
local MAGMA = A.first("cb_blocks:magma", NETHERRACK)
local LAVA, LAVA_FLOWING = "default:lava_source", "default:lava_flowing"
local GOLD = "default:goldblock"
local BRICKS, CHISELED, STONE = "default:stonebrick", "default:stone_block", "default:stone"
local MOSSY = cb_core.equiv("mossy_stone_bricks")
local CRACKED = A.first("cb_blocks:cracked_stone_bricks", BRICKS)
local STAIR = "stairs:stair_stonebrick"
local MOSSY_STAIR = A.first("stairs:stair_cb_mossy_stone_bricks", "stairs:stair_mossycobble", STAIR)
local CRACKED_STAIR = A.first("stairs:stair_cb_cracked_stone_bricks", STAIR)
local SLAB = "stairs:slab_stonebrick"
local MOSSY_SLAB = A.first("stairs:slab_cb_mossy_stone_bricks", "stairs:slab_mossycobble", SLAB)
local CRACKED_SLAB = A.first("stairs:slab_cb_cracked_stone_bricks", SLAB)
local BLACK = A.first("cb_blocks:polished_blackstone", "cb_blocks:blackstone", "default:obsidian")
local BLACK_STAIR = A.first("stairs:stair_cb_polished_blackstone", "stairs:stair_cb_blackstone", STAIR)
local BLACK_SLAB = A.first("stairs:slab_cb_polished_blackstone", "stairs:slab_cb_blackstone", SLAB)
local LEAVES = "default:jungleleaves"
local VINE = A.first("ethereal:vine", "air")

local MAP = {
	["air"] = "air",
	["mcl_nether:netherrack"] = NETHERRACK,
	["mcl_core:lava_source"] = LAVA,
	["mcl_core:lava_flowing"] = LAVA_FLOWING,
	["mcl_core:obsidian"] = OBSIDIAN,
	["mcl_core:goldblock"] = GOLD,
	["mcl_core:stonebrick"] = BRICKS,
	["mcl_core:stonebrickcarved"] = CHISELED,
	["mcl_stairs:slab_stone_double"] = CHISELED,
	["mcl_stairs:slab_stonebrick_double"] = BRICKS,
	["mcl_stairs:slab_stonebrick"] = SLAB,
	["mcl_stairs:slab_stonebrick_top"] = { SLAB, 20, },
	["mcl_stairs:slab_stone"] = A.first("stairs:slab_stone", SLAB),
	["mcl_stairs:stair_stonebrick"] = STAIR,
	["mcl_stairs:stair_stonebrickcracked_inner"] = A.first("stairs:stair_inner_stonebrick", STAIR),
	["mcl_stairs:stair_goldblock"] = A.first("stairs:stair_goldblock", GOLD),
	["mcl_walls:stonebrick"] = A.first("walls:stonebrick", "cb_blocks:stone_brick_wall", BRICKS),
	["mcl_panes:bar_flat"] = A.first("xpanes:bar_flat", "default:fence_wood"),
	["mcl_panes:bar"] = A.first("xpanes:bar", "xpanes:bar_flat", "default:fence_wood"),
	["mcl_fences:nether_brick_fence"] = A.first("nether:fence_nether_brick", "cb_blocks:nether_brick_fence",
		"default:fence_junglewood"),
	["mcl_chests:chest_small"] = "default:chest",
}

local DIR = core.get_modpath("cb_structures") .. "/schematics/mcl_levelgen_ruined_portal_"
RP.SMALL = { "small_1", "small_2", "small_3", "small_4", "small_5", }
RP.LARGE = { "1", "2", "3", }
RP.SCHEMS, RP.unmapped = {}, {}
for _, name in ipairs({ "1", "2", "3", "small_1", "small_2", "small_3", "small_4", "small_5", }) do
	local raw = core.read_schematic(DIR .. name .. ".mts", {})
	local s = { x = raw.size.x, y = raw.size.y, z = raw.size.z, nodes = {}, }
	for i, d in ipairs(raw.data) do
		if (d.prob or 255) > 0 then
			local m = MAP[d.name] or T.MAP[d.name]
			if not m then
				RP.unmapped[d.name] = true
				m = "air"
			end
			local node, p2 = m, d.param2 or 0
			if type(m) == "table" then
				node, p2 = m[1], m[2]
			end
			s.nodes[i] = { node, p2, }
		else
			s.nodes[i] = false
		end
	end
	RP.SCHEMS[name] = s
end

-- The frame of each schematic (found by tools: the 4×5..7×7 rectangle with
-- the most obsidian on its edges): plane axis, the corner along the axis
-- (a), the bottom (y), the other coordinate (c), outer width and height.
RP.FRAMES = {
	["1"] = { "x", 5, 3, 4, 7, 7, }, ["2"] = { "x", 5, 3, 5, 5, 7, }, ["3"] = { "z", 2, 2, 3, 5, 6, },
	small_1 = { "x", 3, 1, 4, 5, 7, }, small_2 = { "x", 3, 2, 2, 4, 5, }, small_3 = { "x", 2, 1, 2, 4, 6, },
	small_4 = { "x", 2, 1, 2, 5, 6, }, small_5 = { "z", 4, 3, 4, 5, 5, },
}

-- Mineclonia's setups per variant: weight, air pocket probability, cold
-- allowed, mossiness, overgrown, vines, placement, blackstone.
local function setup(w, air, cold, moss, over, vines, place, black)
	return { weight = w, air = air, can_be_cold = cold, mossiness = moss, overgrown = over, vines = vines,
		placement = place, blackstone = black, }
end
RP.SETUPS = {
	standard = { setup(0.5, 1.0, true, 0.2, false, false, "underground"),
		setup(0.5, 0.5, true, 0.2, false, false, "on_land_surface"), },
	desert = { setup(1, 0, false, 0, false, false, "partly_buried"), },
	jungle = { setup(1, 0.5, false, 0.8, true, true, "on_land_surface"), },
	swamp = { setup(1, 0, false, 0.5, false, true, "on_ocean_floor"), },
	mountain = { setup(0.5, 1.0, true, 0.2, false, false, "in_mountain"),
		setup(0.5, 0.5, true, 0.2, false, false, "on_land_surface"), },
	ocean = { setup(1, 0, true, 0.8, false, false, "on_ocean_floor"), },
	nether = { setup(1, 0.5, false, 0, false, false, "in_nether", true), },
}
RP.VARIANTS = { "standard", "desert", "jungle", "swamp", "mountain", "ocean", "nether", }

local function chance(rng, p)
	return rng:next(0, 9999) < p * 10000
end

local function walkable(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false
end

-- The ground top under column x, z searching down from y: the first
-- walkable node (on land and on the sea floor alike).
local function ground(x, y, z)
	for yy = y, y - 64, -1 do
		local n = core.get_node(vector.new(x, yy, z)).name
		if n ~= "ignore" and walkable(n) then
			return yy
		end
	end
end

function RP.plan(origin, seed, variant)
	local rng = PcgRandom(seed)
	local setups = RP.SETUPS[variant]
	local cfg = setups[1]
	if #setups > 1 then
		local r, total = rng:next(0, 9999) / 10000, 0
		for _, c in ipairs(setups) do
			total = total + c.weight
		end
		for _, c in ipairs(setups) do
			r = r - c.weight / total
			if r < 0 then
				cfg = c
				break
			end
		end
	end
	local pocket = cfg.air >= 1 or (cfg.air > 0 and chance(rng, cfg.air))
	local giant = rng:next(1, 100) <= RP.GIANT
	local list = giant and RP.LARGE or RP.SMALL
	local name = list[rng:next(1, #list)]
	local s = RP.SCHEMS[name]
	local k = rng:next(0, 3)
	local sx, sz = VS.footprint(s, k)
	local x1, z1 = origin.x - math.floor(sx / 2), origin.z - math.floor(sz / 2)
	local floor = cfg.placement == "on_ocean_floor"
	local g = ground(origin.x, floor and math.max(origin.y, 1) or origin.y, origin.z)
	if not g then
		return nil, S("No ground here for a ruined portal.")
	end
	local height = g + 1
	local base
	if cfg.placement == "on_land_surface" or cfg.placement == "on_ocean_floor" or cfg.placement == "in_nether" then
		base = g
	elseif cfg.placement == "partly_buried" then
		base = height - s.y + 2 + rng:next(0, 6)
	elseif cfg.placement == "underground" then
		base = height - s.y - rng:next(0, 20)
	else
		base = height - s.y
	end
	local data = core.get_biome_data(origin)
	return { schem = name, giant = giant, k = k, x = x1, y = base, z = z1, placement = cfg.placement,
		pocket = pocket, cold = cfg.can_be_cold and data ~= nil and data.heat <= 15, mossiness = cfg.mossiness,
		overgrown = cfg.overgrown, vines = cfg.vines, blackstone = cfg.blackstone, variant = variant, }
end

-- With the nether mod a portal lights only in a 4×5 frame (corners
-- included): there every frame is rebuilt that size, keeping as much of it
-- broken as the schematic's frame was.
local function four_by_five()
	return cb_core.profile.nether ~= "own"
end

-- The opening of the schematic's frame in the world: { pos (bottom, lowest
-- along axis), axis, w, h }, as cb_portals.find_frame returns it.
local function schematic_frame(plan)
	local s, f = RP.SCHEMS[plan.schem], RP.FRAMES[plan.schem]
	local axis, a, y0, c, W, H = f[1], f[2], f[3], f[4], f[5], f[6]
	local function world(u)
		local x, z
		if axis == "x" then
			x, z = a + u, c
		else
			x, z = c, a + u
		end
		local rx, rz = VS.rotate(s, plan.k, x, z)
		return plan.x + rx, plan.z + rz
	end
	local x1, z1 = world(1)
	local x2, z2 = world(W - 2)
	local turned = plan.k % 2 == 1
	local waxis = (axis == "x") ~= turned and "x" or "z"
	return { pos = vector.new(math.min(x1, x2), plan.y + y0 + 1, math.min(z1, z2)), axis = waxis, w = W - 2, h = H - 2, }
end

-- The opening of the frame as built (4×5 outside with the nether mod).
function RP.frame(plan)
	local f = schematic_frame(plan)
	if four_by_five() then
		f.w, f.h = 2, 3
	end
	return f
end

-- The edge cells (corners too) and the opening cells of a frame.
local function frame_cells(f)
	local edge, inside = {}, {}
	for i = -1, f.w do
		for j = -1, f.h do
			local p = vector.offset(f.axis == "x" and vector.offset(f.pos, i, 0, 0) or vector.offset(f.pos, 0, 0, i), 0, j, 0)
			if i == -1 or i == f.w or j == -1 or j == f.h then
				edge[#edge + 1] = p
			else
				inside[#inside + 1] = p
			end
		end
	end
	return edge, inside
end

local function kind(name, p2)
	if name == BRICKS or name == CHISELED or name == STONE or name == MOSSY or name == CRACKED then
		return 0
	elseif name:find("^stairs:stair_") then
		return 1
	elseif name:find("^stairs:slab_") then
		return p2 >= 20 and 3 or 2
	end
end

local function weather(rng, plan, name, p2)
	local t = kind(name, p2)
	local moss = plan.mossiness
	if t == 0 then
		if chance(rng, 0.5) then
			local mossy = moss > 0 and chance(rng, moss)
			if rng:next(0, 1) == 0 then
				return mossy and MOSSY or CRACKED, 0
			end
			return mossy and MOSSY_STAIR or CRACKED_STAIR, rng:next(0, 5)
		end
	elseif t == 1 then
		if chance(rng, 0.5) then
			local mossy = moss > 0 and chance(rng, moss)
			if rng:next(0, 1) == 0 then
				return mossy and MOSSY_SLAB or CRACKED_SLAB, 0
			end
			return mossy and MOSSY_STAIR or CRACKED_STAIR, p2
		end
	elseif t == 2 or t == 3 then
		if moss > 0 and chance(rng, moss) then
			return MOSSY_SLAB, p2
		end
	elseif name == OBSIDIAN and chance(rng, 0.15) then
		return CRYING, p2
	end
	return name, p2
end

local function blackstone(name, p2)
	local t = kind(name, p2)
	if t == 0 then
		return BLACK, 0
	elseif t == 1 then
		return BLACK_STAIR, p2
	elseif t then
		return BLACK_SLAB, p2
	end
	return name, p2
end

local SOLID = {}
local function full(name)
	local v = SOLID[name]
	if v == nil then
		local def = core.registered_nodes[name]
		v = def ~= nil and def.walkable ~= false and (def.drawtype == "normal" or def.drawtype == nil
			or def.drawtype == "glasslike" or def.drawtype == "allfaces_optional")
		SOLID[name] = v
	end
	return v
end

local PROB = { 1, 1, 1, 1, 1, 1, 1, 0.9, 0.9, 0.8, 0.7, 0.6, 0.4, 0.2, }

local function box(plan)
	local s = RP.SCHEMS[plan.schem]
	local sx, sz = VS.footprint(s, plan.k)
	local cx, cz = plan.x + math.floor(sx / 2), plan.z + math.floor(sz / 2)
	local r = RP.RING
	local a = vector.new(math.min(plan.x, cx - r), plan.y - 12, math.min(plan.z, cz - r))
	local b = vector.new(math.max(plan.x + sx - 1, cx + r), plan.y + s.y + 1, math.max(plan.z + sz - 1, cz + r))
	return s, sx, sz, cx, cz, a, b
end

function RP.layout(origin, seed, plan)
	local s, sx, sz, cx, cz, a, b = box(plan)
	local function build(ctx)
		local rng = PcgRandom(seed + 1)
		local floor = plan.placement == "on_ocean_floor"
		-- the ground around before the portal is written (Mineclonia's heightmap)
		local heights = {}
		for x = cx - RP.RING, cx + RP.RING do
			for z = cz - RP.RING, cz + RP.RING do
				for y = b.y, a.y, -1 do
					local n = ctx.get(vector.new(x, y, z))
					if floor and walkable(n) or not floor and n ~= "air" then
						heights[x .. "," .. z] = y + 1
						break
					end
				end
			end
		end
		local function hot(p)
			ctx.set(p, (not plan.cold and chance(rng, 0.07)) and MAGMA or NETHERRACK)
		end
		local function extend(p)
			hot(p)
			for _ = 1, 8 do
				p = vector.offset(p, 0, -1, 0)
				if not chance(rng, 0.5) then
					return
				end
				hot(p)
			end
		end
		-- the schematic
		local i = 0
		for z = 0, s.z - 1 do
			for y = 0, s.y - 1 do
				for x = 0, s.x - 1 do
					i = i + 1
					local n = s.nodes[i]
					if n then
						local name, p2 = n[1], n[2]
						local rx, rz = VS.rotate(s, plan.k, x, z)
						local pos = vector.new(plan.x + rx, plan.y + y, plan.z + rz)
						local keep = false
						if name == GOLD and chance(rng, 0.3) then
							keep = true
						elseif name == "air" then
							local dy = plan.y - pos.y
							local ex = (pos.x - cx) / math.max(1, sx / 2)
							local ez = (pos.z - cz) / math.max(1, sz / 2)
							local ey = dy / math.max(1, s.y)
							keep = not plan.pocket or dy == 0 or ex * ex + ez * ez + ey * ey > 1
						end
						if not keep then
							if not plan.cold and name == NETHERRACK and chance(rng, 0.07) then
								name = MAGMA
							elseif plan.cold and (name == LAVA or name == LAVA_FLOWING) then
								name = NETHERRACK
							end
							name, p2 = weather(rng, plan, name, p2)
							local here = ctx.get(pos)
							if (here == LAVA or here == "nether:lava_source") and not full(name) then
								keep = true
							end
						end
						if not keep then
							if plan.blackstone then
								name, p2 = blackstone(name, p2)
							end
							p2 = T.rotate_param2(name, p2, plan.k)
							if name == "default:chest" then
								ctx.chest(pos, "ruined_portal", p2)
							else
								ctx.set(pos, name, p2)
							end
						end
					end
				end
			end
		end
		if four_by_five() then
			-- the schematic's frame comes down; a 4×5 one as broken goes up in its place
			local empty = (plan.placement == "on_ocean_floor") and function(p)
				return p.y <= 1 and "default:water_source" or "air"
			end or function()
				return "air"
			end
			local old, hit = frame_cells(schematic_frame(plan)), 0
			for _, p in ipairs(old) do
				local n = ctx.get(p)
				if n == OBSIDIAN or n == CRYING then
					hit = hit + 1
					ctx.set(p, empty(p))
				end
			end
			local edge, inside = frame_cells(RP.frame(plan))
			for _, p in ipairs(edge) do
				if chance(rng, hit / #old) then
					ctx.set(p, chance(rng, 0.15) and CRYING or OBSIDIAN)
				end
			end
			for _, p in ipairs(inside) do
				ctx.set(p, empty(p))
			end
		end
		-- netherrack spread over the ground around, then pillars under the floor
		local avg = math.floor((sx + sz) / 2)
		local shrink = rng:next(0, math.max(1, math.floor(8 - avg * 0.5)) - 1)
		local surface = plan.placement == "on_land_surface" or floor
		for x = cx - RP.RING, cx + RP.RING do
			for z = cz - RP.RING, cz + RP.RING do
				local d = math.abs(x - cx) + math.abs(z - cz)
				if d + shrink < RP.RING and rng:next(0, 9999) / 10000 < PROB[d + 1] then
					local h = heights[x .. "," .. z]
					if h then
						if not surface then
							h = math.min(h, plan.y + 1)
						end
						if math.abs(h - 1 - plan.y) <= 3 then
							local p = vector.new(x, h - 1, z)
							local n = ctx.get(p)
							if n ~= "air" and n ~= OBSIDIAN and n ~= "ignore"
									and (plan.placement == "in_nether" or n ~= LAVA) then
								hot(p)
								if plan.overgrown and chance(rng, 0.5) and ctx.get(vector.offset(p, 0, 1, 0)) == "air" then
									ctx.set(vector.offset(p, 0, 1, 0), LEAVES)
								end
								extend(vector.offset(p, 0, -1, 0))
							end
						end
					end
				end
			end
		end
		for x = plan.x, plan.x + sx - 1 do
			for z = plan.z, plan.z + sz - 1 do
				if ctx.get(vector.new(x, plan.y, z)) == NETHERRACK then
					extend(vector.new(x, plan.y - 1, z))
				end
			end
		end
		if plan.vines and VINE ~= "air" then
			local dirs = { vector.new(0, 0, -1), vector.new(-1, 0, 0), vector.new(0, 0, 1), vector.new(1, 0, 0),
				vector.new(0, -1, 0), }
			for x = plan.x, plan.x + sx - 1 do
				for z = plan.z, plan.z + sz - 1 do
					for y = plan.y, plan.y + s.y - 1 do
						local p = vector.new(x, y, z)
						local n = ctx.get(p)
						if n ~= "air" and n ~= VINE and walkable(n) then
							local dir = dirs[rng:next(1, 5)]
							local q = vector.add(p, dir)
							if ctx.get(q) == "air" then
								ctx.set(q, VINE, core.dir_to_wallmounted(vector.multiply(dir, -1)))
							end
						end
					end
				end
			end
		end
	end
	return { minp = a, maxp = b, pieces = { { minp = a, maxp = b, build = build, }, }, }
end

cb_structures.register("ruined_portal", {
	description = S("Ruined Portal"),
	dims = { "overworld", "nether", },
	variants = RP.VARIANTS,
	pick_variant = function(origin)
		if cb_structures.dim_at(origin) == "nether" then
			return "nether"
		end
		if core.get_item_group(core.get_node(origin).name, "water") > 0 then
			return "ocean"
		end
		local data = core.get_biome_data(origin)
		local b = data and core.get_biome_name(data.biome) or ""
		if b:find("desert", 1, true) or b:find("sandstone", 1, true) then
			return "desert"
		elseif b:find("jungle", 1, true) or b:find("rainforest", 1, true) then
			return "jungle"
		elseif b:find("swamp", 1, true) or b:find("mangrove", 1, true) then
			return "swamp"
		elseif origin.y > 60 then
			return "mountain"
		end
		return "standard"
	end,
	prepare = { radius = 32, below = 40, above = 24, },
	plan = RP.plan,
	layout = RP.layout,
})
