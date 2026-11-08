-- Player effects (spec cycle 2, 4.7): poison, slowness, weakness, bad omen
-- and hero (plan 5d). State lives in player meta "cb_effects" (serialized
-- {name = {level, left, acc}}), mirrored in memory for players that have
-- any. Cost: one globalstep every 0.5 s over those players only.
local S = cb_core.S
local E = { defs = {}, PERIOD = 0.5, SAVE_EVERY = 30, }
cb_core.effects = E
local active, huds, unsaved = {}, {}, {}
local KEY = "cb_effects"

function cb_core.difficulty()
	local d = cb_core.setting("cubeborn.difficulty", "normal")
	return (d == "easy" or d == "hard") and d or "normal"
end

function E.register(name, def)
	E.defs[name] = def
end

local function save(player)
	local t = active[player:get_player_name()]
	player:get_meta():set_string(KEY, t and next(t) and core.serialize(t) or "")
end

local function hud(player)
	local pname = player:get_player_name()
	for _, id in pairs(huds[pname] or {}) do
		player:hud_remove(id)
	end
	huds[pname] = {}
	local i = 0
	for name in pairs(active[pname] or {}) do
		local def = E.defs[name]
		if def and def.icon then
			huds[pname][name] = player:hud_add({
				type = "image", hud_elem_type = "image", position = { x = 1, y = 0, },
				offset = { x = -24 - 40 * i, y = 24, }, scale = { x = 2, y = 2, }, text = def.icon,
				alignment = { x = 0, y = 0, },
			})
			i = i + 1
		end
	end
end

function E.apply(player, name, level, seconds)
	local def = assert(E.defs[name], "unknown effect " .. tostring(name))
	local pname = player:get_player_name()
	local t = active[pname] or {}
	local cur = t[name]
	if cur and (cur.level > level or (cur.level == level and cur.left >= seconds)) then
		return
	end
	t[name] = { level = level, left = seconds, acc = cur and cur.acc or 0, }
	active[pname] = t
	if def.on_start then
		def.on_start(player, t[name])
	end
	save(player)
	hud(player)
end

function E.get(player, name)
	local t = active[player:get_player_name()]
	local e = t and t[name]
	if e then
		return e.level, e.left
	end
	return nil
end

function E.clear(player, name)
	local pname = player:get_player_name()
	local t = active[pname]
	if not (t and t[name]) then
		return
	end
	t[name] = nil
	if next(t) == nil then
		active[pname] = nil
	end
	local def = E.defs[name]
	if def and def.on_end then
		def.on_end(player)
	end
	save(player)
	hud(player)
end

-- Every effect at once (death, milk).
function E.clear_all(player)
	for name in pairs(table.copy(active[player:get_player_name()] or {})) do
		E.clear(player, name)
	end
end

function E.step_player(player, dt)
	local t = active[player:get_player_name()]
	for name, e in pairs(t or {}) do
		e.left = e.left - dt
		local def = E.defs[name]
		if def and def.on_tick then
			def.on_tick(player, e, dt)
		end
		if e.left <= 0 then
			E.clear(player, name)
		end
	end
end

-- Join/leave: the meta is the record, memory only while online.
function E.join(player)
	local raw = player:get_meta():get_string(KEY)
	local t = raw ~= "" and core.deserialize(raw) or nil
	if not t or next(t) == nil then
		return
	end
	active[player:get_player_name()] = t
	for name, e in pairs(t) do
		local def = E.defs[name]
		if def and def.on_start then
			def.on_start(player, e)
		end
	end
	hud(player)
end

function E.forget(player)
	local pname = player:get_player_name()
	if active[pname] then
		save(player)
	end
	active[pname], huds[pname], unsaved[pname] = nil, nil, nil
end

-- Effects are saved when they start or end and on leave; their countdown
-- only every SAVE_EVERY s (long effects would write player meta otherwise
-- every step). true when it is time to save.
function E.maybe_save(player, dt)
	local pname = player:get_player_name()
	local t = (unsaved[pname] or 0) + dt
	if t >= E.SAVE_EVERY then
		unsaved[pname] = 0
		return true
	end
	unsaved[pname] = t
	return false
end

core.register_on_joinplayer(E.join)
core.register_on_leaveplayer(E.forget)

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < E.PERIOD then
		return
	end
	local dt = timer
	timer = 0
	if next(active) == nil then
		return
	end
	for pname in pairs(active) do
		local player = core.get_player_by_name(pname)
		if player then
			E.step_player(player, dt)
			if active[pname] and E.maybe_save(player, dt) then
				save(player)
			end
		end
	end
end)

E.register("poison", {
	description = S("Poison"),
	icon = "cb_core_effect_poison.png",
	on_tick = function(player, e, dt)
		e.acc = (e.acc or 0) + dt
		while e.acc >= 1.25 do
			e.acc = e.acc - 1.25
			local hp = player:get_hp()
			if hp > 1 then
				player:set_hp(hp - 1, { type = "set_hp", cause = "cb_poison", })
			end
		end
	end,
})

E.register("slowness", {
	description = S("Slowness"),
	icon = "cb_core_effect_slowness.png",
	on_start = function(player, e)
		cb_core.physics.set_factor(player, "speed", "slowness", math.max(0.1, 1 - 0.15 * e.level))
	end,
	on_end = function(player)
		cb_core.physics.clear_factor(player, "speed", "slowness")
	end,
})

E.register("weakness", { description = S("Weakness"), icon = "cb_core_effect_weakness.png", })

-- Dolphin's Grace: swimming near dolphins is faster.
E.register("dolphins_grace", {
	description = S("Dolphin's Grace"),
	icon = "cb_core_effect_dolphins_grace.png",
	on_start = function(player)
		cb_core.physics.set_factor(player, "speed", "dolphins_grace", 1.5)
	end,
	on_end = function(player)
		cb_core.physics.clear_factor(player, "speed", "dolphins_grace")
	end,
})

-- Mining Fatigue: digging speed x0.3, x0.09, x0.0027, x0.00081 by level, as
-- in Minecraft (the elder guardian's level 3 all but stops it). The time is counted from
-- the first punch at the node; a dig that comes too early is refused, and
-- the server puts the node back on the client.
E.register("mining_fatigue", { description = S("Mining Fatigue"), icon = "cb_core_effect_mining_fatigue.png", })
local first_punch = {}
local FATIGUE_SPEED = { 0.3, 0.09, 0.0027, 0.00081, }

core.register_on_punchnode(function(pos, _, puncher)
	if puncher and puncher:is_player() then
		local name, h = puncher:get_player_name(), core.hash_node_position(pos)
		local fp = first_punch[name]
		if not fp or fp.h ~= h then
			first_punch[name] = { h = h, t = core.get_us_time() / 1e6, }
		end
	end
end)

core.register_on_leaveplayer(function(player)
	first_punch[player:get_player_name()] = nil
end)

-- Seconds a dig must last under the effect, or nil when not fatigued.
function E.fatigue_dig_time(player, node_name)
	local level = E.get(player, "mining_fatigue")
	local def = core.registered_nodes[node_name]
	if not (level and def) then
		return nil
	end
	local tool = player:get_wielded_item()
	local dp = core.get_dig_params(def.groups or {}, tool:get_tool_capabilities(), tool:get_wear())
	return (dp.time or 0) / FATIGUE_SPEED[math.max(1, math.min(4, level))]
end

local node_dig = core.node_dig
function core.node_dig(pos, node, digger)
	if digger and digger:is_player() then
		local need = E.fatigue_dig_time(digger, node.name)
		if need then
			local fp = first_punch[digger:get_player_name()]
			if not (fp and fp.h == core.hash_node_position(pos) and core.get_us_time() / 1e6 - fp.t >= need) then
				return false
			end
		end
	end
	return node_dig(pos, node, digger)
end

-- Wither: one damage every 2 s per level; unlike poison it can kill.
E.register("wither", {
	description = S("Wither"),
	icon = "cb_core_effect_wither.png",
	on_tick = function(player, e, dt)
		local every = 2 / (e.level or 1)
		e.acc = (e.acc or 0) + dt
		while e.acc >= every do
			e.acc = e.acc - every
			local hp = player:get_hp()
			if hp > 0 then
				player:set_hp(hp - 1, { type = "set_hp", cause = "cb_wither", })
			end
		end
	end,
})

-- Regeneration: one HP every 2.5 s at level 1, twice as often per level.
E.register("regeneration", {
	description = S("Regeneration"),
	icon = "cb_core_effect_regeneration.png",
	on_tick = function(player, e, dt)
		local every = 2.5 / 2 ^ ((e.level or 1) - 1)
		e.acc = (e.acc or 0) + dt
		while e.acc >= every do
			e.acc = e.acc - every
			local hp, max = player:get_hp(), player:get_properties().hp_max or 20
			if hp > 0 and hp < max then
				player:set_hp(hp + 1, { type = "set_hp", cause = "cb_regeneration", })
			end
		end
	end,
})

-- Hunger: the stamina mod's food bar drops by one every 15 s per level
-- (Bedrock's Hunger I costs under a food point in 30 s; this stays visible
-- while rotten flesh, +4, is still worth eating).
E.register("hunger", {
	description = S("Hunger"),
	icon = "cb_core_effect_hunger.png",
	on_tick = function(player, e, dt)
		local every = 15 / math.max(1, e.level or 1)
		e.acc = (e.acc or 0) + dt
		while e.acc >= every do
			e.acc = e.acc - every
			if rawget(_G, "stamina") and stamina.change then
				stamina.change(player, -1)
			end
		end
	end,
})

-- Raids (plan 5d): Bad Omen starts a raid in a village; Hero of the Village
-- is the reward (discounts come with trading).
E.register("bad_omen", { description = S("Bad Omen"), icon = "cb_core_effect_bad_omen.png", })
E.register("hero", { description = S("Hero of the Village"), icon = "cb_core_effect_hero.png", })

-- Weakness: a weak player's blows at mobs do half the damage.
function E.weaken(hitter, caps)
	if not (hitter and hitter.is_player and hitter:is_player() and caps and caps.damage_groups) then
		return caps
	end
	if not E.get(hitter, "weakness") then
		return caps
	end
	local c = table.copy(caps)
	for g, v in pairs(c.damage_groups) do
		c.damage_groups[g] = math.floor(v / 2)
	end
	return c
end

core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	local class = mobs and mobs.mob_class
	if not (class and class.on_punch) then
		return
	end
	local on_punch = class.on_punch
	class.on_punch = function(self, hitter, tflp, caps, dir, damage)
		return on_punch(self, hitter, tflp, E.weaken(hitter, caps), dir, damage)
	end
	E.weaken_wrapped = true
end)

-- Blindness: a dark veil over the screen while it lasts.
local veils = {}
E.register("blindness", {
	description = S("Blindness"),
	icon = "cb_core_effect_blindness.png",
	on_start = function(player)
		local name = player:get_player_name()
		if not veils[name] then
			veils[name] = player:hud_add({ type = "image", hud_elem_type = "image", position = { x = 0.5, y = 0.5, },
				scale = { x = -100, y = -100, }, text = "cb_core_blindness.png", alignment = { x = 0, y = 0, }, })
		end
	end,
	on_end = function(player)
		local name = player:get_player_name()
		if veils[name] then
			player:hud_remove(veils[name])
			veils[name] = nil
		end
	end,
})

core.register_on_leaveplayer(function(player)
	veils[player:get_player_name()] = nil
end)

-- Darkness (sculk shriekers, the warden): a vignette that pulses, deeper
-- and lighter in turn, while it lasts.
local shades = {}
local function darkness_text(e)
	local a = 150 + math.floor(105 * (0.5 + 0.5 * math.sin((e.acc or 0) * math.pi / 2)))
	return "cb_core_darkness.png^[opacity:" .. a
end
E.register("darkness", {
	description = S("Darkness"),
	icon = "cb_core_effect_darkness.png",
	on_start = function(player, e)
		local name = player:get_player_name()
		if not shades[name] then
			shades[name] = player:hud_add({ type = "image", hud_elem_type = "image", position = { x = 0.5, y = 0.5, },
				scale = { x = -100, y = -100, }, text = darkness_text(e), alignment = { x = 0, y = 0, }, })
		end
	end,
	on_tick = function(player, e, dt)
		e.acc = (e.acc or 0) + dt
		local id = shades[player:get_player_name()]
		if id then
			player:hud_change(id, "text", darkness_text(e))
		end
	end,
	on_end = function(player)
		local name = player:get_player_name()
		if shades[name] then
			player:hud_remove(shades[name])
			shades[name] = nil
		end
	end,
})

core.register_on_leaveplayer(function(player)
	shades[player:get_player_name()] = nil
end)
