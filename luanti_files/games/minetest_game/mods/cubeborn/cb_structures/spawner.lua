-- Mob spawners of structures (spec 6.3, cycle 2 4.1): a node timer every
-- 10-40 s, so they only work in active blocks near players. With a player
-- within 16 and fewer than 6 of their mobs within 8, they spawn 1-4 mobs in
-- free nodes nearby. The blaze spawner of fortresses, the cave spider
-- spawner of mineshafts, the magma cube spawner of bastions. Only admins (cb_admin) can break them: to everyone
-- else they are protected (machines that respect protection stop too),
-- blast-proof and piston stoppers, so a shared farm cannot be griefed.
local S = cb_structures.S

local sp = {
	MOB = "cb_mobs_dim:blaze",
	RADIUS = 16, CAP_RADIUS = 8, CAP = 6, MIN_T = 10, MAX_T = 40,
}
cb_structures.spawner = sp

local function free(pos)
	return core.get_node(pos).name == "air"
end

-- players: list of positions. Returns how many mobs were spawned.
function sp.tick(pos, players, mob)
	mob = mob or sp.MOB
	if not core.registered_entities[mob] then
		return 0
	end
	local near = false
	for _, p in ipairs(players) do
		if vector.distance(p, pos) <= sp.RADIUS then
			near = true
			break
		end
	end
	if not near then
		return 0
	end
	local count = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, sp.CAP_RADIUS)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == mob then
			count = count + 1
		end
	end
	if count >= sp.CAP then
		return 0
	end
	local spawned = 0
	for _ = 1, math.random(1, 4) do
		for _ = 1, 4 do
			local p = vector.offset(pos, math.random(-4, 4), math.random(-1, 1), math.random(-4, 4))
			if free(p) and free(vector.offset(p, 0, 1, 0)) then
				if core.add_entity(p, mob) then
					spawned = spawned + 1
				end
				break
			end
		end
	end
	return spawned
end

local function start(pos)
	core.get_node_timer(pos):start(math.random(sp.MIN_T, sp.MAX_T))
end

local function admin(player)
	local name = player and player.get_player_name and player:get_player_name() or ""
	return core.check_player_privs(name, { cb_admin = true, })
end

sp.NODES = {}

function sp.register(name, def)
	sp.NODES[name] = true
	if core.get_modpath("mesecons_mvps") then
		mesecon.register_mvps_stopper(name)
	end
	core.register_node(name, {
		description = def.description,
		drawtype = "allfaces",
		tiles = { "cb_structures_blaze_spawner.png", },
		paramtype = "light",
		sunlight_propagates = true,
		groups = { cracky = 1, level = 2, not_in_creative_inventory = 1, },
		drop = "",
		is_ground_content = false,
		sounds = default.node_sound_metal_defaults(),
		can_dig = function(_, player)
			return admin(player)
		end,
		on_blast = function()
		end,
		on_construct = start,
		on_timer = function(pos)
			local players = {}
			for _, player in ipairs(core.get_connected_players()) do
				players[#players + 1] = player:get_pos()
			end
			sp.tick(pos, players, def.mob)
			start(pos)
			return false
		end,
	})
end

sp.register("cb_structures:blaze_spawner", { mob = sp.MOB, description = S("Blaze Spawner"), })
sp.register("cb_structures:silverfish_spawner", { mob = "cb_mobs_overworld:silverfish",
	description = S("Silverfish Spawner"), })
sp.register("cb_structures:cave_spider_spawner", { mob = "cb_mobs_village:cave_spider",
	description = S("Cave Spider Spawner"), })
sp.register("cb_structures:spider_spawner", { mob = "mobs_monster:spider", description = S("Spider Spawner"), })
sp.register("cb_structures:magma_cube_spawner", { mob = "cb_mobs_nether:magma_cube_big",
	description = S("Magma Cube Spawner"), })

local is_protected = core.is_protected
function core.is_protected(pos, name)
	if sp.NODES[core.get_node(pos).name] and not core.check_player_privs(name or "", { cb_admin = true, }) then
		return true
	end
	return is_protected(pos, name)
end
