-- Natural spawning of Cubeborn mobs (spec cycle 4, 2). A rule per mob says
-- where it may appear; one ABM per surface kind (ground, water) fires rarely
-- and then picks a mob among the rules that fit the spot (dimension, light,
-- sky, node, biome, height), checks the category cap within 32 nodes and the
-- mobs_redo switches, and places the mob's group. Cost: 2 ABMs every 30 s;
-- the object count runs only when the ABM chance has hit (a few hits per
-- player and interval).
local SP = { rules = {}, order = {}, CAPS = {}, RADIUS = 32, }
cb_spawning = SP

for cat, n in pairs({ monster = 8, animal = 6, water = 5, ambient = 3, }) do
	SP.CAPS[cat] = tonumber(cb_core.setting("cubeborn.spawn_cap_" .. cat, tostring(n))) or n
end

-- Animals never despawn, and the cap only sees loaded objects: a player who
-- keeps moving would leave a trail of full caps (BACKLOG: too many pigs). So
-- a 64x64 column remembers when it last got an animal group (game time, mod
-- storage, one small key per column) and gets the next one only after
-- ANIMAL_COOLDOWN seconds.
SP.ANIMAL_CELL = 64
SP.ANIMAL_COOLDOWN = tonumber(cb_core.setting("cubeborn.spawn_animal_cooldown", "7200")) or 7200
local storage = core.get_mod_storage()

local function animal_key(pos)
	return "a" .. math.floor(pos.x / SP.ANIMAL_CELL) .. "," .. math.floor(pos.z / SP.ANIMAL_CELL)
end

function SP.animal_rested(pos)
	local t = storage:get_int(animal_key(pos))
	return t == 0 or core.get_gametime() - t >= SP.ANIMAL_COOLDOWN
end

function SP.animal_spawned(pos)
	storage:set_int(animal_key(pos), math.max(1, core.get_gametime()))
end

local MAX_Y = rawget(_G, "cb_dimensions") and cb_dimensions.MAX_Y
	or tonumber(cb_core.setting("cubeborn.pocket_max_y", "-1500")) or -1500
local external_nether = cb_core.profile.nether == "external" and rawget(_G, "nether")
if external_nether and not (external_nether.DEPTH_FLOOR and external_nether.DEPTH_CEILING) then
	external_nether = nil
end

-- "overworld", "nether", "end" or nil (pocket shell, pocket not ready,
-- below the pocket line outside pockets).
function SP.dim_at(pos)
	if rawget(_G, "cb_dimensions") then
		local shell, pocket = cb_dimensions.is_shell(pos)
		if pocket then
			return not shell and pocket.state == "ready" and pocket.dim or nil
		end
	end
	if external_nether and pos.y >= external_nether.DEPTH_FLOOR and pos.y <= external_nether.DEPTH_CEILING then
		return "nether"
	end
	if pos.y > MAX_Y then
		return "overworld"
	end
end

function SP.biome_at(pos)
	local data = core.get_biome_data(pos)
	return data and core.get_biome_name(data.biome) or ""
end

-- rule: see the spec, 2.1. `on` entries are node names or "group:x".
-- dark = true (monsters): Minecraft's rule instead of `light` — no block
-- light at the spot and the sky no brighter than 7 at this time of day.
function SP.register(name, rule)
	rule.light = rule.light or { 0, 15, }
	rule.y = rule.y or { -31000, 31000, }
	rule.weight = rule.weight or 100
	rule.group = rule.group or { 1, 1, }
	-- "water": spawns in water (fish, drowned); "ground": stands on `on`
	rule.kind = rule.kind or (rule.category == "water" and "water" or "ground")
	if not SP.rules[name] then
		SP.order[#SP.order + 1] = name
	end
	SP.rules[name] = rule
end

local function node_fits(name, list)
	for _, want in ipairs(list) do
		if want == name or (want:sub(1, 6) == "group:" and core.get_item_group(name, want:sub(7)) > 0) then
			return true
		end
	end
	return false
end

local function biome_fits(pos, words)
	if not words then
		return true
	end
	local b = SP.biome_at(pos)
	for _, w in ipairs(words) do
		if b:find(w, 1, true) then
			return true
		end
	end
	return false
end

local function free(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def ~= nil and def.walkable == false and (def.liquidtype or "none") == "none"
end

-- Where the mob would be: above the ground node, or in the water node.
local function spot_of(pos, kind)
	return kind == "water" and vector.copy(pos) or vector.offset(pos, 0, 1, 0)
end

function SP.candidates(pos, node, kind)
	local spot = spot_of(pos, kind)
	if kind == "ground" and not (free(spot) and free(vector.offset(spot, 0, 1, 0))) then
		return {}
	end
	local dim = SP.dim_at(spot)
	if not dim then
		return {}
	end
	local light = core.get_node_light(spot) or 0
	local block, sky_now, sky
	local out = {}
	for _, name in ipairs(SP.order) do
		local r = SP.rules[name]
		if r.kind == kind and core.registered_entities[name] and table.indexof(r.dims, dim) > 0
				and spot.y >= r.y[1] and spot.y <= r.y[2] and node_fits(node.name, r.on) then
			local lit_ok
			if r.dark then
				-- Minecraft darkness: no block light, and the sky no brighter than
				-- 7 now (Luanti's open sky never drops to 0 at night)
				if block == nil then
					local n = core.get_node(spot)
					block = core.get_artificial_light(n.param1)
					sky_now = core.get_natural_light(spot) or 0
				end
				lit_ok = block == 0 and sky_now <= 7
			else
				lit_ok = light >= r.light[1] and light <= r.light[2]
			end
			if r.sky ~= nil and sky == nil then
				sky = (core.get_natural_light(spot, 0.5) or 0) >= 15
			end
			if lit_ok and (r.sky == nil or r.sky == sky) and biome_fits(spot, r.biomes) and (not r.check or r.check(spot)) then
				out[#out + 1] = { name, r, }
			end
		end
	end
	return out
end

function SP.pick(cands, rand)
	local total = 0
	for _, c in ipairs(cands) do
		total = total + c[2].weight
	end
	local x = (rand or math.random()) * total
	for _, c in ipairs(cands) do
		x = x - c[2].weight
		if x <= 0 then
			return c[1], c[2]
		end
	end
	local last = cands[#cands]
	return last and last[1], last and last[2]
end

local category_of = {}

-- The animal cap counts every animal mob (mobs_animal's cows and sheep too).
function SP.capped(pos, category)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, SP.RADIUS)) do
		local e = obj:get_luaentity()
		local r = e and SP.rules[e.name]
		if (r and r.category == category)
				or (not r and category == "animal" and e and e._cmi_is_mob and e.type == "animal") then
			n = n + 1
		end
	end
	return n >= (SP.CAPS[category] or 0)
end

local function blocked(spot, rule)
	if not core.settings:get_bool("mobs_spawn", true) then
		return true
	end
	if rule.category == "monster" then
		if core.settings:get_bool("only_peaceful_mobs", false) then
			return true
		end
		if not core.settings:get_bool("mobs_spawn_protected", true) and core.is_protected(spot, "") then
			return true
		end
	end
	local range = tonumber(core.settings:get("mob_nospawn_range") or 12) or 12
	for _, p in ipairs(core.get_connected_players()) do
		local pp = p:get_pos()
		if pp and vector.distance(pp, spot) <= range then
			return true
		end
	end
	return false
end

-- The whole ABM action without its chance: returns how many mobs it placed.
function SP.try(pos, node, kind, rand)
	local cands = SP.candidates(pos, node, kind)
	if #cands == 0 then
		return 0
	end
	local name, rule = SP.pick(cands, rand)
	local spot = spot_of(pos, kind)
	local animal = rule.category == "animal"
	if blocked(spot, rule) or (animal and not SP.animal_rested(spot)) or SP.capped(spot, rule.category) then
		return 0
	end
	local placed = 0
	for i = 1, math.random(rule.group[1], rule.group[2]) do
		local p = i == 1 and spot or vector.offset(spot, math.random(-2, 2), 0, math.random(-2, 2))
		if i == 1 or (kind == "water" and core.get_item_group(core.get_node(p).name, "water") > 0)
				or (kind == "ground" and free(p) and free(vector.offset(p, 0, 1, 0))) then
			if core.add_entity(vector.offset(p, 0, kind == "ground" and 0.5 or 0, 0), name) then
				placed = placed + 1
			end
		end
	end
	if animal and placed > 0 then
		SP.animal_spawned(spot)
	end
	return placed
end

local scale = tonumber(cb_core.setting("cubeborn.spawn_chance_scale", "1")) or 1
core.register_abm({
	label = "cb_spawning ground",
	-- Nether floors are in none of those groups; unknown names are ignored
	nodenames = { "group:soil", "group:stone", "group:sand", "default:gravel", "default:snowblock",
		"default:dirt_with_snow",
		"nether:rack", "nether:rack_deep", "nether:sand", "nether:basalt", "nether:lava_source",
		"cb_blocks:netherrack", "cb_blocks:soul_sand", "cb_blocks:soul_soil", "cb_blocks:crimson_nylium",
		"cb_blocks:warped_nylium", "cb_blocks:blackstone", "cb_blocks:basalt", "default:lava_source", },
	-- the nether mod's dark air over fumaroles is air too
	neighbors = { "air", "nether:airlike_darkness", },
	interval = 30,
	-- 1/8000 left about one pack mob within 32 of a player at night: most
	-- hits land on cave stone and monsters despawn after 3 minutes (BACKLOG 20)
	chance = math.max(1, math.floor(2000 * scale)),
	catch_up = false,
	action = function(pos, node)
		SP.try(pos, node, "ground")
	end,
})
core.register_abm({
	label = "cb_spawning water",
	nodenames = { "default:water_source", "default:river_water_source", },
	neighbors = { "default:water_source", "default:river_water_source", },
	interval = 30,
	chance = math.max(1, math.floor(4000 * scale)),
	catch_up = false,
	action = function(pos, node)
		SP.try(pos, node, "water")
	end,
})
