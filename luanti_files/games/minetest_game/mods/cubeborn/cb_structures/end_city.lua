-- End city (spec 6.2): Mineclonia's End city templates and pools assembled
-- by cb_structures.jigsaw. Every template is a part; shulkers come from the
-- templates' data blocks and the respawn engine, chests get the
-- end_city_treasure loot, and the ship's elytra stand on a 3d_armor stand.
local S = cb_structures.S
local T, J = cb_structures.templates, cb_structures.jigsaw
local DIR = core.get_modpath("cb_structures") .. "/templates/"
local EC = { MAX_DEPTH = 25, RADIUS = 110, MAX_PIECES = 80, MARGIN = 2, }
cb_structures.end_city = EC

local cache = {}
local function L(name, weight)
	cache[name] = cache[name] or T.load(DIR .. name .. ".dat")
	return { tpl = cache[name], weight = weight, }
end

J.register_pool("mcl_end:end_city_starts", { L("end_city_base_tower", 1), })
J.register_pool("mcl_end:end_city_towers", { L("end_city_small_tower_base", 1), })
J.register_pool("mcl_end:small_tower_middle_pieces", {
	L("end_city_small_tower_independent", 1), L("end_city_small_tower_1_branch", 2),
	L("end_city_small_tower_2_branch", 2), L("end_city_small_tower_3_branch", 2), L("end_city_small_tower_4_branch", 1),
})
J.register_pool("mcl_end:small_tower_top_buildings", { L("end_city_small_tower_building_1", 1), })
J.register_pool("mcl_end:small_tower_building_extensions", { L("end_city_small_tower_building_2", 1), })
J.register_pool("mcl_end:tower_bridges", { L("end_city_tower_bridge", 2), L("end_city_end_ship_dock_1", 1), }, true)
J.register_pool("mcl_end:end_ship_dock_extensions", { L("end_city_end_ship_dock_2", 1), })
J.register_pool("mcl_end:bridge_extensions", {
	L("end_city_tower_bridge_extension", 4), L("end_city_steps_steep", 6), L("end_city_end_ship_dock", 1),
})
J.register_pool("mcl_end:house_steps", { L("end_city_steps_steep", 1), })
J.register_pool("mcl_end:houses", { L("end_city_house_basic", 1), L("end_city_house_2layer", 3), })
J.register_pool("mcl_end:house_roof", { L("end_city_house_basic_roof", 1), })
J.register_pool("mcl_end:roof_2layer", { L("end_city_house_layer_2", 1), })
J.register_pool("mcl_end:roof_3layer", { L("end_city_roof_layer_2", 1), L("end_city_house_loot_floor", 2), })
J.register_pool("mcl_end:end_ships", { L("end_city_ship", 1), })
EC.SHIP = cache.end_city_ship

local function pocket_at(pos)
	for _, p in pairs(cb_dimensions.all()) do
		local a, b = cb_dimensions.inner(p)
		if cb_core.inside(pos, a, b) then
			return a, b
		end
	end
end

-- Level coordinates: anchor at origin, world = origin + (x, y, -z); the
-- first tower is centred on origin with its floor at origin.y - 1.
function EC.layout(origin, seed)
	local R = EC.RADIUS
	local bounds = { -R, -R, -R, R, R, R, }
	local ia, ib = pocket_at(origin)
	if ia then
		local m = EC.MARGIN
		bounds = { math.max(-R, ia.x + m - origin.x), math.max(-R, ia.y + m - origin.y), math.max(-R, origin.z - (ib.z - m)),
			math.min(R, ib.x - m - origin.x), math.min(R, ib.y - m - origin.y), math.min(R, origin.z - (ia.z + m)), }
	end
	local pieces = J.assemble("mcl_end:end_city_starts", PcgRandom(seed), -8, -1, -8,
		{ max_depth = EC.MAX_DEPTH, max_pieces = EC.MAX_PIECES, bounds = bounds, })
	local out, lo, hi, ship = {}, nil, nil, false
	for _, p in ipairs(pieces) do
		local a = vector.new(origin.x + p.bbox[1], origin.y + p.bbox[2], origin.z - p.bbox[6])
		local b = vector.new(origin.x + p.bbox[4], origin.y + p.bbox[5], origin.z - p.bbox[3])
		ship = ship or p.tpl == EC.SHIP
		out[#out + 1] = { minp = a, maxp = b, part = true, build = function(ctx)
			local actions = T.place(ctx, p.tpl, origin, p.x, p.y, p.z, p.k)
			ctx.after(function()
				EC.act(actions)
			end)
		end, }
		lo = lo and vector.new(math.min(lo.x, a.x), math.min(lo.y, a.y), math.min(lo.z, a.z)) or vector.copy(a)
		hi = hi and vector.new(math.max(hi.x, b.x), math.max(hi.y, b.y), math.max(hi.z, b.z)) or vector.copy(b)
	end
	return { minp = lo, maxp = hi, pieces = out, ship = ship, }
end

EC.COUNT = tonumber(cb_core.setting("cubeborn.end_cities", "3")) or 3
EC.SPACING = 180
local STAND = "3d_armor_stand:armor_stand"
local SHULKER_FACES = { "up", "down", "north", "south", "east", "west", }

local function stand_slot(inv)
	-- Older 3d_armor_stand (ta) keeps one list per element.
	if inv:get_size("armor_torso") > 0 then
		return "armor_torso", 1
	end
	return "main", 2
end

local function put_on_stand(p, stack)
	local inv = core.get_meta(p):get_inventory()
	local list, index = stand_slot(inv)
	inv:set_stack(list, index, stack)
	local def = core.registered_nodes[STAND]
	if def.on_metadata_inventory_put then
		def.on_metadata_inventory_put(p, list, index, stack)
	end
end

-- The ship's elytra: on an armour stand on the floor under the frame, or in
-- a chest there when 3d_armor_stand is missing.
function EC.place_elytra(pos, param2, stands)
	local p = vector.copy(pos)
	for _ = 1, 3 do
		local below = core.registered_nodes[core.get_node(vector.offset(p, 0, -1, 0)).name]
		if below and below.walkable ~= false then
			break
		end
		p.y = p.y - 1
	end
	local stack = ItemStack("cb_items:elytra_wings")
	if stands and core.registered_nodes[STAND] then
		core.set_node(p, { name = STAND, param2 = core.dir_to_facedir(core.wallmounted_to_dir(param2)), })
		if core.get_node(vector.offset(p, 0, 1, 0)).name == "air" and core.registered_nodes["3d_armor_stand:top"] then
			core.set_node(vector.offset(p, 0, 1, 0), { name = "3d_armor_stand:top", })
		end
		put_on_stand(p, stack)
	else
		core.set_node(p, { name = "default:chest", })
		core.get_meta(p):get_inventory():add_item("main", stack)
	end
end

-- The ship's elytra comes back cubeborn.elytra_respawn_days (7) days of real
-- time after it was taken (respawn.lua checks each part once a minute while a
-- player is near). The stand is found once per part and kept in part.ey
-- (false: no stand there); a broken stand is put back, a slot holding
-- anything else is left alone.
function EC.restock(rec, part, id)
	if part.ey == false or not core.registered_nodes[STAND] then
		return
	end
	local first = part.ey == nil
	if first then
		local found = core.find_nodes_in_area(part.minp, part.maxp, { STAND, })[1]
		if found then
			part.ey, part.ep = found, core.get_node(found).param2
		else
			part.ey = false
		end
		cb_structures.registry.save(id)
		if not found then
			return
		end
	end
	local p = part.ey
	local name = core.get_node(p).name
	if name == "ignore" then
		return
	end
	local stack
	if name == STAND then
		local inv = core.get_meta(p):get_inventory()
		stack = inv:get_stack(stand_slot(inv))
	end
	local has = stack ~= nil and stack:get_name() == "cb_items:elytra_wings"
	local wait = (tonumber(cb_core.setting("cubeborn.elytra_respawn_days", "7")) or 7) * 86400
	if first and not has then
		-- taken before this check existed: wait from now, no free elytra
		part.rare = part.rare or {}
		part.rare.y = os.time() + wait
		cb_structures.registry.save(id)
		return
	end
	if not cb_structures.respawn.rare_ready(id, part, "y", has, wait) or has then
		return
	end
	if name == "air" then
		core.set_node(p, { name = STAND, param2 = part.ep or 0, })
		if core.get_node(vector.offset(p, 0, 1, 0)).name == "air" and core.registered_nodes["3d_armor_stand:top"] then
			core.set_node(vector.offset(p, 0, 1, 0), { name = "3d_armor_stand:top", })
		end
		stack = ItemStack("")
	elseif name ~= STAND or not stack:is_empty() then
		return
	end
	put_on_stand(p, ItemStack("cb_items:elytra_wings"))
	cb_structures.respawn.rare_given(id, part, "y")
end

function EC.act(actions)
	for _, a in ipairs(actions) do
		if a.kind == "entity" and a.what == "mobs_mc:shulker" and cb_mobs_dim and cb_mobs_dim.shulker then
			local Sh = cb_mobs_dim.shulker
			local spawned = false
			for _, face in ipairs(SHULKER_FACES) do
				if not spawned and Sh.valid(face, a.pos) then
					spawned = Sh.spawn(a.pos, face) ~= nil
				end
			end
			if not spawned then
				core.add_entity(vector.offset(a.pos, 0, -0.5, 0), "cb_mobs_dim:shulker", core.serialize({ face = "up", }))
			end
		elseif a.kind == "frame" then
			EC.place_elytra(a.pos, a.param2, true)
		end
	end
end

local EXCLUDE = { ["default:chest"] = true, ["default:chest_open"] = true, [STAND] = true, ["3d_armor_stand:top"] = true,
	["cb_blocks:dragon_head_wall"] = true, }

cb_structures.register("end_city", {
	description = S("End City"),
	dims = { "end", },
	layout = EC.layout,
	inhabitants = { mobs = { { "cb_mobs_dim:shulker", 1, }, }, volume = 400, max = 2, },
	sample_exclude = EXCLUDE,
	restock = EC.restock,
})

-- Spots on the outer islands: on the ring halfway between outer_r and the
-- pocket edge, over islands at least 4 thick, SPACING apart, at most COUNT.
function EC.spots(pocket)
	local te = cb_dimensions.the_end
	local g = te.geometry(pocket)
	local half = math.min(g.ib.x - g.centre.x, g.ib.z - g.centre.z) - te.EDGE - 40
	local r = (g.outer_r + half) / 2
	local spots = {}
	if r <= g.outer_r then
		return spots
	end
	for a = 0, 23 do
		local ang = a * math.pi / 12
		local x = math.floor(g.centre.x + r * math.cos(ang) + 0.5)
		local z = math.floor(g.centre.z + r * math.sin(ang) + 0.5)
		local lo, hi = te.outer_range(g, x, z)
		if hi and hi - lo >= 4 then
			local far = true
			for _, s in ipairs(spots) do
				far = far and vector.distance(vector.new(s.x, 0, s.z), vector.new(x, 0, z)) >= EC.SPACING
			end
			if far then
				spots[#spots + 1] = vector.new(x, hi + 1, z)
				if #spots >= EC.COUNT then
					break
				end
			end
		end
	end
	return spots
end

function EC.auto(pocket)
	for _, s in ipairs(EC.spots(pocket)) do
		cb_structures.place("end_city", s, pocket.created_by, function(res)
			if not res.ok then
				core.log("action", "[cubeborn] End city at " .. core.pos_to_string(s) .. " skipped: "
					.. core.get_translated_string("en", res.msg))
			end
		end)
	end
end

local te = cb_dimensions.the_end
if te and te.ready_hooks then
	table.insert(te.ready_hooks, EC.auto)
end
