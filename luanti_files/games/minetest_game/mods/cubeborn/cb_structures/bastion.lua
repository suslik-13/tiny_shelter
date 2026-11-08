-- Bastion remnant (spec cycle 4, 8d). As in Bedrock one of four kinds: the
-- treasure bastion from Mineclonia's templates and pools (assembled by
-- cb_structures.jigsaw, weathered like Mineclonia's processor), or housing
-- units, a hoglin stable or a bridge (bastion_builds.lua, Secret Terra's
-- layouts). Piglins (a piglin brute now and then) live in every part; the
-- brute is a rare inhabitant. Chests use Bedrock's bastion loot.
local S = cb_structures.S
local T, J = cb_structures.templates, cb_structures.jigsaw
local E = cb_core.equiv
local DIR = core.get_modpath("cb_structures") .. "/templates/"
local B = { RADIUS = 80, MAX_DEPTH = 20, MAX_PIECES = 400, MARGIN = 2, TREASURE_Y = 29, BUILD_Y = 33, }
cb_structures.bastion = B
B.PIGLIN, B.BRUTE, B.HOGLIN = "cb_mobs_nether:piglin", "cb_mobs_nether:piglin_brute", "cb_mobs_nether:hoglin"
B.KINDS = { "treasure", "units", "stable", "bridge", }

local BRICKS, CRACKED = "cb_blocks:polished_blackstone_bricks", "cb_blocks:cracked_polished_blackstone_bricks"
local BLACKSTONE, GILDED, GOLD = "cb_blocks:blackstone", "cb_blocks:gilded_blackstone", "default:goldblock"
local M = T.MAP
M["mcl_blackstone:blackstone"] = BLACKSTONE
M["mcl_blackstone:blackstone_brick_polished"] = BRICKS
M["mcl_blackstone:blackstone_gilded"] = GILDED
M["mcl_blackstone:blackstone_polished"] = "cb_blocks:polished_blackstone"
M["mcl_blackstone:basalt"] = E("basalt")
M["mcl_blackstone:basalt_smooth"] = "cb_blocks:smooth_basalt"
M["mcl_stairs:stair_blackstone"] = "stairs:stair_cb_blackstone"
M["mcl_stairs:slab_blackstone"] = "stairs:slab_cb_blackstone"
M["mcl_stairs:stair_blackstone_brick_polished"] = "stairs:stair_cb_polished_blackstone_bricks"
M["mcl_stairs:slab_blackstone_brick_polished"] = "stairs:slab_cb_polished_blackstone_bricks"
M["mcl_lanterns:chain"] = "cb_blocks:chain"
M["mcl_lanterns:lantern_floor"] = "cb_blocks:lantern"
M["mcl_lanterns:lantern_ceiling"] = "cb_blocks:lantern_hanging"
M["mcl_nether:nether_lava_source"] = "default:lava_source"
M["mcl_nether:glowstone"] = E("glowstone")
M["mcl_core:goldblock"] = GOLD
M["mcl_mobspawners:spawner"] = "cb_structures:magma_cube_spawner"

local cache = {}
local function L(name, weight)
	cache[name] = cache[name] or T.load(DIR .. name .. ".dat")
	return { tpl = cache[name], weight = weight, }
end
local P = "mcl_levelgen:"
J.register_pool(P .. "bastion_starts", { L("bastion_treasure_start_aerated", 1), })
J.register_pool(P .. "bastion_treasure_bridges", { L("bastion_treasure_entrance", 1), })
J.register_pool(P .. "bastion_treasure_walls", {
	L("bastion_treasure_wall", 1), L("bastion_treasure_wall_corner", 1), L("bastion_treasure_facade_wall", 1),
})
J.register_pool(P .. "bastion_treasure_basins", { L("bastion_treasure_basin", 1), })
J.register_pool(P .. "bastion_treasure_corridors", {
	L("bastion_treasure_corridor_basic", 5), L("bastion_treasure_corridor_basic_1", 5),
	L("bastion_treasure_corridor_basic_2", 5), L("bastion_treasure_corridor_extrusion_1", 3),
	L("bastion_treasure_corridor_down_1", 1),
})
J.register_pool(P .. "bastion_treasure_corridors_bottom", { L("bastion_treasure_corridor_bottom", 10), })
J.register_pool(P .. "bastion_treasure_plugs", { L("bastion_treasure_corridor_plug", 10), })
J.register_pool(P .. "bastion_treasure_interior_bridges", { L("bastion_treasure_bridge", 10), })
J.register_pool(P .. "bastion_spawners", { L("bastion_spawner_magma_cube", 10), })
J.register_pool(P .. "bastion_treasure_roofs", { L("bastion_treasure_roof", 1), })
J.register_pool(P .. "bastion_treasure_pillars", { L("bastion_treasure_pillar", 1), })
J.register_pool(P .. "bastion_treasure_rooms", { L("bastion_treasure_room_1", 1), })
J.register_pool(P .. "bastion_treasure_extrusions", { L("bastion_treasure_extrusion_1", 1), L("bastion_treasure_extrusion_2", 1), })
J.register_pool(P .. "bastion_treasure_ramparts", { L("bastion_treasure_rampart", 1), })
B.START = cache.bastion_treasure_start_aerated
B.TEMPLATES = cache

-- A number in [0, 1) from a position and a seed (cheap and repeatable).
function B.hash(x, y, z, seed)
	local h = bit.bxor(x * 73856093, y * 19349663, z * 83492791, seed)
	h = bit.bxor(h, bit.rshift(h, 13)) * 1274126177 % 4294967296
	h = bit.bxor(h, bit.rshift(h, 16))
	return (h % 65536) / 65536
end

-- Mineclonia's bastion_generic_degredation.
function B.weather(name, pos, seed)
	if name == BRICKS then
		return B.hash(pos.x, pos.y, pos.z, seed) < 0.3 and CRACKED or name
	elseif name == BLACKSTONE then
		local r = B.hash(pos.x, pos.y, pos.z, seed)
		return r < 0.0001 and "air" or r < 0.0101 and GILDED or name
	elseif name == GOLD then
		return B.hash(pos.x, pos.y, pos.z, seed) < 0.3 and "air" or name
	elseif name == GILDED then
		return B.hash(pos.x, pos.y, pos.z, seed) < 0.5 and BLACKSTONE or name
	end
	return name
end

-- Mineclonia's tables for the piglin data blocks (crossbow piglins are
-- plain piglins here); false: nobody.
B.ROLLS = {
	["mcl_levelgen:piglin"] = { { B.BRUTE, 1, }, { B.PIGLIN, 5, }, { false, 20, }, },
	["mcl_levelgen:piglin_melee"] = { { B.BRUTE, 6, }, { B.PIGLIN, 1, }, { false, 20, }, },
}

function B.roll(list, r)
	local total = 0
	for _, m in ipairs(list) do
		total = total + m[2]
	end
	local n = (r or math.random()) * total
	for _, m in ipairs(list) do
		n = n - m[2]
		if n < 0 then
			return m[1]
		end
	end
	return false
end

function B.act(actions)
	for _, a in ipairs(actions) do
		local list = a.kind == "entity" and B.ROLLS[a.what]
		local mob = list and B.roll(list)
		if mob and core.registered_entities[mob] then
			core.add_entity(vector.offset(a.pos, 0, 0.5, 0), mob)
		end
	end
end

local function pocket_at(pos)
	for _, p in pairs(cb_dimensions.all()) do
		local a, b = cb_dimensions.inner(p)
		if cb_core.inside(pos, a, b) then
			return a, b
		end
	end
end

-- The ground level of the buildings: in a pocket from its floor, elsewhere
-- origin.y. Returns base y and the pocket's inner box (if any).
function B.base(origin, above_floor)
	local ia, ib = pocket_at(origin)
	return ia and ia.y + above_floor or origin.y, ia, ib
end

-- Treasure bastion. Level coordinates: anchor (origin.x, base, origin.z),
-- world = anchor + (x, y, -z); the start piece is centred on the anchor.
function B.treasure_layout(origin, seed)
	local base, ia, ib = B.base(origin, B.TREASURE_Y)
	local R, m = B.RADIUS, B.MARGIN
	local bounds = { -R, -40, -R, R, 90, R, }
	if ia then
		bounds = { math.max(-R, ia.x + m - origin.x), ia.y + m - base, math.max(-R, origin.z - (ib.z - m)),
			math.min(R, ib.x - m - origin.x), ib.y - m - base, math.min(R, origin.z - (ia.z + m)), }
	end
	local start = B.START
	local pieces = J.assemble(P .. "bastion_starts", PcgRandom(seed), -math.floor(start.w / 2), 0, -math.floor(start.l / 2),
		{ max_depth = B.MAX_DEPTH, max_pieces = B.MAX_PIECES, bounds = bounds, })
	local anchor = vector.new(origin.x, base, origin.z)
	local opts = { loot = "bastion_treasure", process = function(name, pos)
		return B.weather(name, pos, seed)
	end, }
	local out, lo, hi = {}, nil, nil
	for _, p in ipairs(pieces) do
		local a = vector.new(anchor.x + p.bbox[1], anchor.y + p.bbox[2], anchor.z - p.bbox[6])
		local b = vector.new(anchor.x + p.bbox[4], anchor.y + p.bbox[5], anchor.z - p.bbox[3])
		out[#out + 1] = { minp = a, maxp = b, part = p.tpl ~= B.START, kind = "treasure", build = function(ctx)
			local actions = T.place(ctx, p.tpl, anchor, p.x, p.y, p.z, p.k, opts)
			ctx.after(function()
				B.act(actions)
			end)
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	return { minp = lo, maxp = hi, pieces = out, }
end

function B.layout(origin, seed, plan)
	local kind = plan and plan.variant or "treasure"
	if kind == "treasure" then
		return B.treasure_layout(origin, seed)
	end
	return B.build_layout(origin, seed, kind)
end

local PIGLINS = { mobs = { { B.PIGLIN, 4, }, { B.BRUTE, 1, "b", }, }, volume = 2000, max = 2, }
cb_structures.register("bastion", {
	description = S("Bastion Remnant"),
	dims = { "nether", },
	variants = B.KINDS,
	pick_variant = function()
		return B.KINDS[math.random(#B.KINDS)]
	end,
	prepare = { radius = 1, below = 1, above = 1, },
	plan = function(_, _, variant)
		return { variant = variant, }
	end,
	layout = B.layout,
	inhabitants = { kinds = {
		treasure = PIGLINS, units = PIGLINS, bridge = PIGLINS,
		stable = { mobs = { { B.HOGLIN, 3, }, { B.PIGLIN, 2, }, { B.BRUTE, 1, "b", }, }, volume = 2000, max = 3, },
	}, },
	sample_exclude = {
		["default:lava_source"] = true, ["default:lava_flowing"] = true, ["default:chest"] = true,
		["default:chest_open"] = true, ["cb_structures:magma_cube_spawner"] = true, [GOLD] = true,
		["cb_blocks:lantern"] = true, ["cb_blocks:lantern_hanging"] = true, ["cb_blocks:chain"] = true,
	},
})

-- tiny: two bastions when the own Nether pocket becomes ready, in the two
-- quarters the fortresses leave free (after them).
function B.auto(pocket)
	local ia, ib = cb_dimensions.inner(pocket)
	local w, d = ib.x - ia.x, ib.z - ia.z
	for _, q in ipairs({ { 0.25, 0.75, }, { 0.75, 0.25, }, }) do
		local origin = vector.new(ia.x + math.floor(w * q[1]), ia.y, ia.z + math.floor(d * q[2]))
		cb_structures.place("bastion", origin, pocket.created_by, function(res)
			if not res.ok then
				core.log("action", "[cubeborn] bastion at " .. core.pos_to_string(origin) .. " skipped: "
					.. core.get_translated_string("en", res.msg))
			end
		end)
	end
end

local nether = cb_core.profile.nether == "own" and cb_dimensions.get_dim("nether")
if nether then
	local before = nether.on_ready
	cb_dimensions.set_on_ready("nether", function(pocket)
		if before then
			before(pocket)
		end
		B.auto(pocket)
	end)
end
