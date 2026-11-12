-- Trial spawners and vaults (plan 8f-1), Bedrock rules without ominous
-- trials. A trial spawner wakes when a player comes within 14 (creative
-- players too: the servers' admins have the creative privilege): it calls 6
-- mobs plus 2 for each further player there, at most 2 plus 1 per further
-- player at a time, one every 2 s within 4 of it. When the last
-- one is gone, every player of the trial gets a trial key and a little food,
-- and the spawner sleeps for 30 real minutes (kept in its meta, so restarts
-- do not reset it). A vault takes a trial key and gives its loot once to
-- each player. Mobs come from the spawner's pool (its meta "mob"; the
-- structure picks it). Only admins (cb_admin) can break either: to everyone
-- else they are protected and blast-proof. Node timers: they only work near
-- players.
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.SPAWNER, T.SPAWNER_ACTIVE = "cb_mobs_trial:trial_spawner", "cb_mobs_trial:trial_spawner_active"
T.VAULT, T.VAULT_ACTIVE, T.KEY = "cb_mobs_trial:vault", "cb_mobs_trial:vault_active", "cb_mobs_trial:trial_key"
T.HEAVY_CORE = "cb_mobs_trial:heavy_core"
local TS = { RANGE = 14, SPREAD = 4, EVERY = 2, COOLDOWN = 1800, TICK = 1, VAULT_RANGE = 4, }
T.trial = TS

-- Mob pools of the structure's spawners (what the server has).
TS.POOLS = {
	melee = { "cb_mobs_overworld:zombie", "cb_mobs_overworld:husk", "mobs_monster:spider", },
	small_melee = { "mobs_slimes:greensmall", "cb_mobs_overworld:silverfish", "cb_mobs_overworld:zombie:baby",
		"cb_mobs_village:cave_spider", },
	ranged = { "cb_mobs_overworld:stray", "mobs_skeletons:skeleton_archer", "cb_mobs_trial:bogged", "cb_mobs_trial:breeze", },
}

-- A mob of the pool the server has ("name:baby" for a baby), or nil.
function TS.pick(pool)
	local have = {}
	for _, m in ipairs(TS.POOLS[pool] or {}) do
		if core.registered_entities[m:gsub(":baby$", "")] then
			have[#have + 1] = m
		end
	end
	return #have > 0 and have[math.random(#have)] or nil
end

-- Loot: pools of { items = candidates, w = weight, n = {min, max} }; the
-- first registered candidate counts, entries with none drop out.
local function roll(pools)
	local out = {}
	for _, pool in ipairs(pools) do
		local entries, total = {}, 0
		for _, e in ipairs(pool.entries) do
			local item = false
			for _, c in ipairs(e.items or {}) do
				if core.registered_items[c] then
					item = c
					break
				end
			end
			if item or not e.items then
				entries[#entries + 1] = { item = item, w = e.w, n = e.n, }
				total = total + e.w
			end
		end
		for _ = 1, math.random(pool.rolls[1], pool.rolls[2]) do
			local r = math.random(1, math.max(total, 1))
			for _, e in ipairs(entries) do
				r = r - e.w
				if r <= 0 then
					if e.item then
						out[#out + 1] = ItemStack(e.item .. " " .. (e.n and math.random(e.n[1], e.n[2]) or 1))
					end
					break
				end
			end
		end
	end
	return out
end
T.roll = roll

local function e(items, w, a, b)
	return { items = items, w = w, n = a and { a, b, } or nil, }
end
-- Bedrock's trial chamber consumables (one roll per player).
TS.CONSUMABLES = { { rolls = { 1, 1, }, entries = { e({ "farming:bread", }, 3, 1, 3), e({ "mobs:chicken_cooked", }, 3, 1, 3),
	e({ "farming:baked_potato", }, 2, 2, 4), e({ "farming:carrot_gold", }, 1, 1, 2), }, }, }
-- Bedrock's vault loot without bows, arrows, wind charges, shields, potions,
-- discs; the heavy core (Bedrock: ominous vaults), bolt and flow templates are the rare ones.
local EMERALD, IRON, DIAMOND = { "cb_items:emerald", }, { "default:steel_ingot", }, { "default:diamond", }
local ROD = { "cb_mobs_trial:breeze_rod", }
TS.VAULT_LOOT = {
	{ rolls = { 1, 1, }, entries = { e(EMERALD, 392, 2, 4), e(IRON, 69, 1, 4), e({ "farming:carrot_gold", }, 200, 1, 2),
		e(ROD, 23, 1, 3), e(DIAMOND, 23, 1, 2), e({ "default:book", }, 200), e({ "default:axe_steel", }, 200),
		e({ "3d_armor:chestplate_steel", }, 200), e({ "default:axe_diamond", }, 100), e({ "3d_armor:chestplate_diamond", }, 100), }, },
	{ rolls = { 1, 3, }, entries = { e(EMERALD, 4, 2, 4), e(IRON, 3, 1, 4), e(ROD, 1, 1, 3), e(DIAMOND, 1, 1, 2), }, },
	{ rolls = { 1, 1, }, entries = { e(nil, 36), e({ "ethereal:golden_apple", }, 4), e({ T.HEAVY_CORE, }, 3),
		e({ "cb_items:trim_bolt", }, 3), e({ "cb_items:trim_flow", }, 3), }, },
}

local function eject(pos, stacks)
	for _, st in ipairs(stacks) do
		local obj = core.add_item(vector.offset(pos, 0, 1, 0), st)
		if obj then
			obj:set_velocity(vector.new(math.random(-10, 10) / 10, 3, math.random(-10, 10) / 10))
		end
	end
end

local function admin(player)
	local name = player and player.get_player_name and player:get_player_name() or ""
	return core.check_player_privs(name, { cb_admin = true, })
end

local function players_near(pos, r)
	local out = {}
	for _, p in ipairs(core.get_connected_players()) do
		local at = p:get_pos()
		if at and vector.distance(at, pos) <= r and p:get_hp() > 0 then
			out[#out + 1] = p
		end
	end
	return out
end
TS.players_near = players_near

-- Live waves by spawner position (mobs are not saved: a restart ends a wave).
local waves = {}
TS.waves = waves

local function swap(pos, name)
	local node = core.get_node(pos)
	if node.name ~= name then
		core.swap_node(pos, { name = name, param2 = node.param2, })
	end
end

local function free(p)
	return core.get_node(p).name == "air" and core.get_node(vector.offset(p, 0, 1, 0)).name == "air"
end

-- One mob of the spawner's kind near pos, or nil.
function TS.spawn_one(pos, mob)
	local name, baby = mob:gsub(":baby$", "")
	for _ = 1, 8 do
		local p = vector.offset(pos, math.random(-TS.SPREAD, TS.SPREAD), math.random(-1, 1), math.random(-TS.SPREAD, TS.SPREAD))
		if free(p) then
			local obj = core.add_entity(p, name)
			local ent = obj and obj:get_luaentity()
			local Z = rawget(_G, "cb_mobs_overworld")
			if ent and baby > 0 and Z and Z.make_baby and not ent.child then
				ent._baby = true
				Z.make_baby(ent)
			end
			if obj then
				core.add_particlespawner({ amount = 8, time = 0.3, minpos = vector.offset(p, -0.4, 0, -0.4),
					maxpos = vector.offset(p, 0.4, 1.5, 0.4), minexptime = 0.4, maxexptime = 0.8, minsize = 2, maxsize = 4,
					texture = "cb_mobs_trial_wind_burst.png^[colorize:#f0a040:180", glow = 12, })
			end
			return obj
		end
	end
	return nil
end

-- One step of the spawner at pos (every TICK s; dt = real seconds). Returns
-- its state: "cooldown", "waiting", "wave" or "done".
function TS.tick(pos, dt)
	local meta = core.get_meta(pos)
	local h = core.hash_node_position(pos)
	local w = waves[h]
	if not w then
		if os.time() < meta:get_int("cooldown_until") then
			swap(pos, T.SPAWNER)
			return "cooldown"
		end
		local near = TS.players_near(pos, TS.RANGE)
		if #near == 0 then
			swap(pos, T.SPAWNER)
			return "waiting"
		end
		local mob = meta:get_string("mob")
		if mob == "" then
			mob = TS.pick(meta:get_string("pool") ~= "" and meta:get_string("pool") or "melee")
			meta:set_string("mob", mob or "")
		end
		if not mob or not core.registered_entities[mob:gsub(":baby$", "")] then
			return "waiting"
		end
		local n = #near
		w = { mob = mob, total = 6 + 2 * (n - 1), at_once = 2 + (n - 1), spawned = 0, alive = {}, t = TS.EVERY,
			players = {}, }
		for _, p in ipairs(near) do
			w.players[p:get_player_name()] = true
		end
		waves[h] = w
		swap(pos, T.SPAWNER_ACTIVE)
	end
	for _, p in ipairs(TS.players_near(pos, TS.RANGE)) do
		w.players[p:get_player_name()] = true
	end
	local alive = {}
	for _, obj in ipairs(w.alive) do
		local ent = obj:get_pos() and obj:get_luaentity()
		if ent and (ent.health or 1) > 0 then
			alive[#alive + 1] = obj
		end
	end
	w.alive = alive
	w.t = w.t + dt
	if w.spawned < w.total and #alive < w.at_once and w.t >= TS.EVERY then
		local obj = TS.spawn_one(pos, w.mob)
		if obj then
			w.t, w.spawned = 0, w.spawned + 1
			w.alive[#w.alive + 1] = obj
		end
	end
	if w.spawned >= w.total and #w.alive == 0 then
		local stacks = {}
		for _ in pairs(w.players) do
			stacks[#stacks + 1] = ItemStack(T.KEY)
			for _, st in ipairs(roll(TS.CONSUMABLES)) do
				stacks[#stacks + 1] = st
			end
		end
		eject(pos, stacks)
		core.sound_play("cb_mobs_trial_breeze_burst", { pos = pos, gain = 0.6, max_hear_distance = 16, }, true)
		waves[h] = nil
		meta:set_int("cooldown_until", os.time() + TS.COOLDOWN)
		swap(pos, T.SPAWNER)
		return "done"
	end
	return "wave"
end

local function start(pos)
	core.get_node_timer(pos):start(TS.TICK)
end

local protected = {}
local function guarded(def)
	def.can_dig = function(_, player)
		return admin(player)
	end
	def.on_blast = function() end
	def.drop = ""
	def.is_ground_content = false
	def.paramtype2 = "facedir"
	return def
end

local function spawner(name, side, top, light, hidden)
	protected[name] = true
	core.register_node(name, guarded({
		description = S("Trial Spawner"),
		drawtype = "allfaces",
		tiles = { "cb_mobs_trial_spawner_" .. top .. ".png", "cb_mobs_trial_spawner_bottom.png",
			"cb_mobs_trial_spawner_" .. side .. ".png", },
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		light_source = light,
		groups = { cracky = 1, level = 2, not_in_creative_inventory = hidden and 1 or nil, },
		sounds = default.node_sound_metal_defaults(),
		on_construct = start,
		on_timer = function(pos, elapsed)
			TS.tick(pos, elapsed)
			return true
		end,
	}))
end
spawner(T.SPAWNER, "side", "top", 4)
spawner(T.SPAWNER_ACTIVE, "side_on", "top_on", 8, true)

-- Vaults: a key opens one for each player once.
local function rewarded(meta)
	return core.deserialize(meta:get_string("rewarded")) or {}
end

-- player uses a key on the vault at pos: true when it paid out.
function TS.open_vault(pos, player, itemstack)
	local name = player:get_player_name()
	local meta = core.get_meta(pos)
	local done = rewarded(meta)
	if itemstack:get_name() ~= T.KEY or done[name] then
		if itemstack:get_name() == T.KEY then
			core.chat_send_player(name, S("This vault has already rewarded you."))
		end
		return false
	end
	done[name] = true
	meta:set_string("rewarded", core.serialize(done))
	if not core.is_creative_enabled(name) then
		itemstack:take_item()
	end
	swap(pos, T.VAULT_ACTIVE)
	core.get_node_timer(pos):start(1.5)
	core.sound_play("cb_mobs_trial_breeze_burst", { pos = pos, gain = 0.4, max_hear_distance = 12, }, true)
	eject(pos, roll(TS.VAULT_LOOT))
	return true
end

local function vault(name, state, hidden)
	protected[name] = true
	core.register_node(name, guarded({
		description = S("Vault"),
		tiles = { "cb_mobs_trial_vault_top_" .. state .. ".png", "cb_mobs_trial_vault_bottom.png",
			"cb_mobs_trial_vault_side_" .. state .. ".png", "cb_mobs_trial_vault_side_" .. state .. ".png",
			"cb_mobs_trial_vault_side_" .. state .. ".png", "cb_mobs_trial_vault_front_" .. state .. ".png", },
		paramtype = "light",
		light_source = state == "on" and 6 or 3,
		groups = { cracky = 1, level = 2, not_in_creative_inventory = hidden and 1 or nil, },
		sounds = default.node_sound_metal_defaults(),
		on_rightclick = function(pos, _, clicker, itemstack)
			if clicker and clicker:is_player() then
				TS.open_vault(pos, clicker, itemstack)
			end
			return itemstack
		end,
		on_timer = function(pos)
			swap(pos, T.VAULT)
			return false
		end,
	}))
end
vault(T.VAULT, "off")
vault(T.VAULT_ACTIVE, "on", true)

core.register_craftitem(T.KEY, { description = S("Trial Key"), inventory_image = "cb_mobs_trial_trial_key.png", })

local is_protected = core.is_protected
function core.is_protected(pos, name)
	if protected[core.get_node(pos).name] and not core.check_player_privs(name or "", { cb_admin = true, }) then
		return true
	end
	return is_protected(pos, name)
end
if core.get_modpath("mesecons_mvps") then
	for n in pairs(protected) do
		mesecon.register_mvps_stopper(n)
	end
end
