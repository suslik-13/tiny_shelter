-- Sculk (plan 8e): sculk, veins, sensors, shriekers and catalysts. They only
-- listen inside ancient cities (cb_structures records of type
-- "ancient_city"): every 0.5 s a player who moved there without sneaking
-- wakes the sensors within 8, and a woken sensor (or stepping on a
-- shrieker) makes the shriekers within 8 shriek. A shrieker the city placed
-- (param2 1) raises that player's warning level (one step per 10 s, back
-- down one per 10 minutes), darkens players within 40 and, at level 4,
-- calls cb_mobs_deep.summon_warden. A mob dying within 8 of a catalyst
-- turns up to 5 bare stone blocks around it to sculk. Outside the cities
-- nothing here costs anything. Textures: Mineclonia mcl_sculk; the active
-- sensor and the sounds are secret_terra's own (st_mobs).
local S = cb_mobs_deep.S
local D = cb_mobs_deep
local K = {
	PERIOD = 0.5, HEAR = 8, MOVE = 0.3, ACTIVE = 1.5, SHRIEK_RANGE = 8, SHRIEK_TIME = 4.5,
	COOLDOWN = 10, DECAY = 600, MAX_WARNING = 4, DARKNESS_RANGE = 40, DARKNESS_TIME = 13,
	BLOOM_RANGE = 8, BLOOM_RADIUS = 3, BLOOM_NODES = 5,
}
D.sculk = K
D.SCULK, D.VEIN, D.CATALYST = "cb_mobs_deep:sculk", "cb_mobs_deep:sculk_vein", "cb_mobs_deep:sculk_catalyst"
D.SENSOR, D.SHRIEKER = "cb_mobs_deep:sculk_sensor", "cb_mobs_deep:sculk_shrieker"
local SENSOR_ACTIVE = D.SENSOR .. "_active"

-- warden.lua replaces these when mobs_redo is there.
function D.summon_warden(pos, name)
	return nil
end
function D.warden_near(pos)
	return false
end

local function tex(name)
	return "cb_mobs_deep_" .. name .. ".png"
end
local sounds = {
	footstep = { name = "cb_mobs_deep_sculk_block", gain = 0.2, },
	dug = { name = "cb_mobs_deep_sculk_block", gain = 0.4, },
}
local SLAB = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0, 0.5, }, }

-- Sculk blocks drop nothing (no silk touch here), only experience.
local function xp(n)
	return function(pos, _, _, digger)
		if digger and digger:is_player() and not core.is_creative_enabled(digger:get_player_name())
				and rawget(_G, "cb_xp") then
			cb_xp.drop(pos, n)
		end
	end
end

core.register_node(D.SCULK, {
	description = S("Sculk"),
	tiles = { { name = tex("sculk"), animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3, }, }, },
	groups = { crumbly = 3, sculk = 1, },
	drop = "",
	is_ground_content = false,
	sounds = sounds,
	after_dig_node = xp(1),
})

core.register_node(D.VEIN, {
	description = S("Sculk Vein"),
	drawtype = "signlike",
	tiles = { tex("sculk_vein"), },
	inventory_image = tex("sculk_vein"),
	wield_image = tex("sculk_vein"),
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	selection_box = { type = "wallmounted", },
	groups = { snappy = 3, sculk = 1, },
	drop = "",
	is_ground_content = false,
	sounds = sounds,
})

local function slab(name, desc, kind, extra)
	local def = {
		description = desc,
		drawtype = "nodebox",
		node_box = SLAB,
		selection_box = SLAB,
		collision_box = SLAB,
		tiles = { tex(kind .. "_top"), tex(kind .. "_bottom"), tex(kind .. "_side"), },
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		groups = { crumbly = 2, sculk = 1, },
		drop = "",
		is_ground_content = false,
		sounds = sounds,
		after_dig_node = xp(5),
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	core.register_node(name, def)
end

slab(D.SENSOR, S("Sculk Sensor"), "sculk_sensor", { light_source = 1, })
slab(SENSOR_ACTIVE, S("Sculk Sensor"), "sculk_sensor", {
	tiles = { tex("sculk_sensor_top_active"), tex("sculk_sensor_bottom_active"), tex("sculk_sensor_side_active"), },
	light_source = 6,
	groups = { crumbly = 2, sculk = 1, not_in_creative_inventory = 1, },
	on_timer = function(pos)
		core.swap_node(pos, { name = D.SENSOR, })
	end,
})
-- param2 1: set by a city, can call the warden; one a player sets cannot.
slab(D.SHRIEKER, S("Sculk Shrieker"), "sculk_shrieker", { place_param2 = 0, })

core.register_node(D.CATALYST, {
	description = S("Sculk Catalyst"),
	tiles = { tex("sculk_catalyst_top"), tex("sculk_catalyst_bottom"), tex("sculk_catalyst_side"), },
	light_source = 6,
	groups = { crumbly = 2, sculk = 1, },
	drop = "",
	is_ground_content = false,
	sounds = sounds,
	after_dig_node = xp(5),
})

-- Ancient city loot; the recovery compass it makes in Minecraft is not here.
core.register_craftitem("cb_mobs_deep:echo_shard", {
	description = S("Echo Shard"),
	inventory_image = tex("echo_shard"),
})

-- The ancient city at pos, if any.
function K.city_at(pos)
	local found
	cb_structures.registry.parts_near(pos, 0, function(_, _, rec)
		if rec.type == "ancient_city" then
			found = rec
			return false
		end
	end)
	return found
end

-- The cube of radius r around pos, cut to the city's box.
local function clip(pos, r, rec)
	local a, b = rec.minp, rec.maxp
	return vector.new(math.max(pos.x - r, a.x), math.max(pos.y - r, a.y), math.max(pos.z - r, a.z)),
		vector.new(math.min(pos.x + r, b.x), math.min(pos.y + r, b.y), math.min(pos.z + r, b.z))
end

local function within(pos, r, rec, names)
	local out, a, b = {}, clip(pos, r, rec)
	for _, p in ipairs(core.find_nodes_in_area(a, b, names)) do
		if vector.distance(p, pos) <= r then
			out[#out + 1] = p
		end
	end
	return out
end

-- Warning level: player meta, decays one step per DECAY seconds of game time.
function K.get_warning(player)
	local meta = player:get_meta()
	local level, t = meta:get_int("cb_warden_warning"), meta:get_float("cb_warden_warning_time")
	local now = core.get_gametime()
	if level > 0 and now - t >= K.DECAY then
		local lost = math.floor((now - t) / K.DECAY)
		level = math.max(0, level - lost)
		meta:set_int("cb_warden_warning", level)
		meta:set_float("cb_warden_warning_time", t + lost * K.DECAY)
	end
	return level
end

function K.set_warning(player, level)
	local meta = player:get_meta()
	meta:set_int("cb_warden_warning", level)
	meta:set_float("cb_warden_warning_time", core.get_gametime())
end

local busy = {}
-- The shrieker at pos shrieks because of player (or nobody); false while
-- it is still shrieking.
function K.shriek(pos, player)
	local h = core.hash_node_position(pos)
	if busy[h] then
		return false
	end
	busy[h] = true
	core.after(K.SHRIEK_TIME, function()
		busy[h] = nil
	end)
	core.sound_play("cb_mobs_deep_sculk_shriek", { pos = pos, gain = 1.5, max_hear_distance = 32, }, true)
	core.add_particlespawner({
		amount = 12, time = K.SHRIEK_TIME * 0.6,
		minpos = vector.offset(pos, -0.2, 0.1, -0.2), maxpos = vector.offset(pos, 0.2, 0.2, 0.2),
		minvel = vector.new(0, 1.2, 0), maxvel = vector.new(0, 2, 0),
		minexptime = 1.2, maxexptime = 1.6, minsize = 4, maxsize = 6,
		texture = tex("sculk_vein") .. "^[colorize:#69b6c4:160", glow = 8,
	})
	if not (player and player:is_player()) or core.get_node(pos).param2 ~= 1 then
		return true
	end
	local meta, now = player:get_meta(), core.get_gametime()
	local last = meta:get_float("cb_warden_last")
	if (last > 0 and now - last < K.COOLDOWN) or D.warden_near(pos) then
		return true
	end
	meta:set_float("cb_warden_last", now)
	local level = math.min(K.MAX_WARNING, K.get_warning(player) + 1)
	K.set_warning(player, level)
	for _, p in ipairs(core.get_connected_players()) do
		if vector.distance(p:get_pos(), pos) <= K.DARKNESS_RANGE then
			cb_core.effects.apply(p, "darkness", 1, K.DARKNESS_TIME)
		end
	end
	if level >= K.MAX_WARNING then
		local name = player:get_player_name()
		core.after(K.SHRIEK_TIME, function()
			-- the same player, unless they left (an old object has no position)
			local pl = core.get_player_by_name(name) or (player:get_pos() and player)
			if not D.warden_near(pos) and D.summon_warden(pos, name) and pl then
				K.set_warning(pl, 0)
			end
		end)
	end
	return true
end

-- The sensor at pos hears player: it lights up and the shriekers near it shriek.
function K.activate(pos, player, rec)
	core.swap_node(pos, { name = SENSOR_ACTIVE, })
	core.get_node_timer(pos):start(K.ACTIVE)
	core.sound_play("cb_mobs_deep_sculk_click", { pos = pos, gain = 0.6, max_hear_distance = 16, }, true)
	for _, s in ipairs(within(pos, K.SHRIEK_RANGE, rec, { D.SHRIEKER, })) do
		K.shriek(s, player)
	end
end

-- player, in city rec, was at prev half a second ago.
function K.listen(player, pos, prev, rec)
	if player:get_player_control().sneak then
		return
	end
	local feet = vector.round(pos)
	if core.get_node(feet).name == D.SHRIEKER then
		K.shriek(feet, player)
	end
	if vector.distance(pos, prev) < K.MOVE then
		return
	end
	for _, p in ipairs(within(pos, K.HEAR, rec, { D.SENSOR, })) do
		K.activate(p, player, rec)
	end
end

local last, timer = {}, 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < K.PERIOD then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name, pos = player:get_player_name(), player:get_pos()
		local prev = last[name]
		last[name] = pos
		if prev and not core.is_creative_enabled(name) then
			local rec = K.city_at(pos)
			if rec then
				K.listen(player, pos, prev, rec)
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	last[player:get_player_name()] = nil
end)

-- Catalyst: a death at pos within BLOOM_RANGE of one spreads sculk over the
-- bare ground around pos. Returns how many blocks turned.
local SPREAD = { "default:stone", "default:cobble", "default:dirt", "default:gravel", "cb_blocks:deepslate",
	"cb_blocks:cobbled_deepslate", }
function K.bloom(pos)
	local rec = K.city_at(pos)
	if not rec then
		return 0
	end
	pos = vector.round(pos)
	if #within(pos, K.BLOOM_RANGE, rec, { D.CATALYST, }) == 0 then
		return 0
	end
	local a, b = clip(pos, K.BLOOM_RADIUS, rec)
	local spots = core.find_nodes_in_area_under_air(a, b, SPREAD)
	local n = 0
	while #spots > 0 and n < K.BLOOM_NODES do
		local p = table.remove(spots, math.random(#spots))
		if not core.is_protected(p, "") then
			core.set_node(p, { name = D.SCULK, })
			n = n + 1
		end
	end
	if n > 0 then
		core.sound_play("cb_mobs_deep_sculk_block", { pos = pos, gain = 1, max_hear_distance = 16, }, true)
	end
	return n
end

core.register_on_mods_loaded(function()
	local mobs = rawget(_G, "mobs")
	if not (mobs and mobs.mob_class and mobs.mob_class.item_drop) then
		return
	end
	local item_drop = mobs.mob_class.item_drop
	mobs.mob_class.item_drop = function(self, ...)
		local p = self.object:get_pos()
		if p then
			K.bloom(p)
		end
		return item_drop(self, ...)
	end
end)

core.register_on_dieplayer(function(player)
	K.bloom(player:get_pos())
end)
