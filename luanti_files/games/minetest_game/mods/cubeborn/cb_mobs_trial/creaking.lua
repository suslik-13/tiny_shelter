-- Creaking and creaking heart (plan 8f-2), Bedrock behaviour after secret
-- terra's st_mobs creaking (its model, textures and sounds). A creaking heart
-- set between two pale oak logs along its axis sleeps by day and wakes at
-- night; awake, with a player (not in creative) within 32 it calls one
-- creaking within 16. A creaking is calm until a player looks at it from
-- within 12; then it hunts that player, but stands frozen while any player
-- looks at it, and strikes (3) when nobody does. It forgets its target
-- beyond 24. While its heart stands nothing hurts it: blows make it sway and
-- make the heart ooze resin clumps. Breaking the heart makes it twitch and
-- crumble; it also crumbles at dawn or 34+ from its heart. A creaking from
-- an egg has 1 HP and no heart. Hearts drop 1-3 resin clumps, a natural one
-- (pale groves) 20-24 experience too. The players' pumpkin-on-the-head trick
-- does not exist here (MTG players wear no pumpkins).
local S = cb_mobs_trial.S
local T = cb_mobs_trial
T.CREAKING, T.HEART = "cb_mobs_trial:creaking", "cb_mobs_trial:creaking_heart"
local C = { SPAWN_PLAYER = 32, SPAWN_XZ = 16, SPAWN_Y = 8, HOME = 34, LOOK_NEUTRAL = 12, LOOK_HOSTILE = 24,
	ATTACK_COOLDOWN = 2, TWITCH = 2.25, LOOK_EVERY = 0.1, }
T.creaking = C
local LOG = "cb_blocks:pale_oak_log"
local CLUMP = "cb_blocks:resin_clump"

-- Bedrock: creakings exist between 18:36 and 05:24.
function C.night()
	local tod = core.get_timeofday()
	return tod > 0.775 or tod < 0.225
end

local function axis_of(param2)
	local a = math.floor((param2 or 0) / 4)
	if a == 1 or a == 2 then
		return vector.new(0, 0, 1)
	elseif a == 3 or a == 4 then
		return vector.new(1, 0, 0)
	end
	return vector.new(0, 1, 0)
end

function C.between_logs(pos, node)
	local ax = axis_of(node.param2)
	return core.get_node(vector.add(pos, ax)).name == LOG and core.get_node(vector.subtract(pos, ax)).name == LOG
end

local bound = {}
local function key(pos)
	return core.hash_node_position(vector.round(pos))
end
function C.bound(pos)
	local obj = bound[key(pos)]
	if obj and obj:get_pos() then
		return obj
	end
	bound[key(pos)] = nil
	return nil
end

local function survivor(p)
	return p and p:get_pos() and p:is_player() and p:get_hp() > 0 and not core.is_creative_enabled(p:get_player_name())
end

-- Is the creaking at pos inside player's view (120 degrees, its head, body
-- or feet unobstructed) within range?
function C.looked_at(pos, player, range)
	if not survivor(player) then
		return false
	end
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height or 1.6, 0)
	if vector.distance(eye, pos) > range then
		return false
	end
	local look = player:get_look_dir()
	for _, dy in ipairs({ 2.4, 1.4, 0.5, }) do
		local p = vector.offset(pos, 0, dy, 0)
		if vector.dot(look, vector.direction(eye, p)) >= 0.5 and core.line_of_sight(eye, p) then
			return true
		end
	end
	return false
end

-- Players that might look at it (tests replace this).
function C.watchers()
	return core.get_connected_players()
end

local function eyes(self)
	local active = self._state == "hostile" or self._state == "twitching"
	local tex = active and "cb_mobs_trial_creaking_active.png" or "cb_mobs_trial_creaking.png"
	if self._eyes ~= tex then
		self._eyes = tex
		self.object:set_properties({ textures = { tex, }, })
	end
end

local function sound(self, name, gain)
	core.sound_play(name, { pos = self.object:get_pos(), gain = gain or 0.8, max_hear_distance = 16, }, true)
end

function C.crumble(self)
	if self._state == "crumbling" then
		return
	end
	self._state = "crumbling"
	local pos = self.object:get_pos()
	sound(self, "cb_mobs_trial_creaking_crumble", 1)
	core.add_particlespawner({
		amount = 40, time = 0.3, minpos = vector.offset(pos, -0.4, 0, -0.4), maxpos = vector.offset(pos, 0.4, 2.6, 0.4),
		minvel = vector.new(-1, 0, -1), maxvel = vector.new(1, 1.5, 1), minacc = vector.new(0, -9, 0),
		maxacc = vector.new(0, -9, 0), minexptime = 0.6, maxexptime = 1.2, minsize = 1, maxsize = 2.5,
		collisiondetection = true, texture = "cb_blocks_pale_oak_log.png",
	})
	if self._heart then
		bound[key(self._heart)] = nil
	end
	-- no drops, no experience
	self.object:remove()
end

function C.twitch(self)
	if self._state == "twitching" or self._state == "crumbling" then
		return
	end
	self._state, self._twitch, self._frozen = "twitching", C.TWITCH, nil
	self:stop_attack()
	self:set_animation("twitch", true)
	eyes(self)
end

function C.hostile(self, player)
	self._state, self._target = "hostile", player
	self:do_attack(player)
	sound(self, "cb_mobs_trial_creaking_unfreeze")
	eyes(self)
end

function C.neutral(self)
	self._state, self._target, self._frozen = "neutral", nil, nil
	self:stop_attack()
	eyes(self)
end

local function freeze(self, frozen)
	if self._frozen == frozen then
		return
	end
	self._frozen = frozen
	self.object:set_animation_frame_speed(frozen and 0 or 30)
	sound(self, frozen and "cb_mobs_trial_creaking_freeze" or "cb_mobs_trial_creaking_unfreeze", 0.6)
end

-- Resin oozes from the heart when its creaking is hurt by a player.
function C.heart_hurt(heart, from)
	if core.get_item_group(core.get_node(heart).name, "creaking_heart") == 0 then
		return 0
	end
	local spots = {}
	for _, d in ipairs({ { 1, 0, 0, }, { -1, 0, 0, }, { 0, 0, 1, }, { 0, 0, -1, }, { 0, 1, 0, }, { 0, -1, 0, }, }) do
		local p = vector.offset(heart, d[1], d[2], d[3])
		local def = core.registered_nodes[core.get_node(p).name]
		if def and not def.walkable then
			spots[#spots + 1] = p
		end
	end
	local n = math.random(2, 3)
	for _ = 1, n do
		core.add_item(#spots > 0 and spots[math.random(#spots)] or vector.offset(heart, 0, 1, 0), CLUMP)
	end
	if from then
		local dir, dist = vector.direction(from, heart), vector.distance(from, heart)
		core.add_particlespawner({ amount = math.min(60, math.floor(dist * 4)), time = 0.5,
			minpos = vector.offset(from, 0, 1.2, 0), maxpos = vector.offset(from, 0, 1.6, 0),
			minvel = vector.multiply(dir, dist), maxvel = vector.multiply(dir, dist * 1.25), minexptime = 0.8,
			maxexptime = 1, minsize = 1, maxsize = 2, texture = "cb_mobs_trial_creaking_heart_top_awake.png^[resize:2x2",
			glow = 8, })
	end
	return n
end

-- do_custom: false keeps mobs_redo out while it twitches or stands frozen.
function C.step(self, dtime)
	local pos = self.object:get_pos()
	if self._state == "twitching" then
		self._twitch = self._twitch - dtime
		if self._twitch <= 0 then
			C.crumble(self)
		end
		return false
	end
	if self._state == "crumbling" or not pos then
		return false
	end
	if self._heart then
		local hnode = core.get_node(self._heart)
		if hnode.name ~= "ignore" then
			if core.get_item_group(hnode.name, "creaking_heart") == 0 then
				C.twitch(self)
				return false
			end
			bound[key(self._heart)] = self.object
		end
		if (self.nametag or "") == "" and (not C.night() or vector.distance(pos, self._heart) > C.HOME) then
			C.crumble(self)
			return false
		end
	end
	self._look_t = (self._look_t or 0) + dtime
	local look = self._look_t >= C.LOOK_EVERY
	if look then
		self._look_t = 0
	end
	if (self._state or "neutral") == "neutral" then
		if look then
			for _, p in ipairs(C.watchers()) do
				if C.looked_at(pos, p, C.LOOK_NEUTRAL) then
					C.hostile(self, p)
					break
				end
			end
		end
		return true
	end
	local target = self._target
	if not survivor(target) or vector.distance(pos, target:get_pos()) > C.LOOK_HOSTILE then
		C.neutral(self)
		return true
	end
	if look then
		local watched = false
		for _, p in ipairs(C.watchers()) do
			if C.looked_at(pos, p, C.LOOK_HOSTILE) then
				watched = true
				break
			end
		end
		freeze(self, watched)
	end
	if self._frozen then
		local v = self.object:get_velocity()
		self.object:set_velocity(vector.new(0, math.min(v.y, 0), 0))
		return false
	end
	if self.attack ~= target then
		self:do_attack(target)
	end
	return true
end

mobs:register_mob(T.CREAKING, {
	type = "monster", passive = false, attack_type = "dogfight", damage = 3, reach = 2.5, punch_interval = C.ATTACK_COOLDOWN,
	hp_min = 1, hp_max = 1, armor = 100, knock_back = false,
	collisionbox = { -0.45, 0, -0.45, 0.45, 2.7, 0.45, },
	visual = "mesh", mesh = "cb_mobs_trial_creaking.b3d", visual_size = { x = 1, y = 1, },
	textures = { { "cb_mobs_trial_creaking.png", }, },
	walk_velocity = 1.5, run_velocity = 3, stepheight = 1.1, view_range = C.LOOK_HOSTILE, fear_height = 4,
	water_damage = 0, lava_damage = 4, light_damage = 0, fall_damage = false, makes_footstep_sound = true,
	drops = {},
	sounds = { random = "cb_mobs_trial_creaking_idle", attack = "cb_mobs_trial_creaking_attack",
		damage = "cb_mobs_trial_creaking_sway", death = "cb_mobs_trial_creaking_crumble", distance = 16, },
	animation = { speed_normal = 30, stand_start = 0, stand_end = 1, walk_start = 2, walk_end = 22, run_start = 2,
		run_end = 22, run_speed = 40, punch_start = 23, punch_end = 38, twitch_start = 39, twitch_end = 51, },
	do_custom = C.step,
	do_punch = function(self, hitter)
		if self._state == "twitching" or self._state == "crumbling" then
			return false
		end
		if not self._heart then
			return true
		end
		sound(self, "cb_mobs_trial_creaking_sway")
		if hitter and hitter:is_player() then
			C.heart_hurt(self._heart, self.object:get_pos())
			if (self._state or "neutral") == "neutral" then
				C.hostile(self, hitter)
			end
		end
		return false
	end,
	after_activate = function(self)
		-- targets come only from looks
		self.general_attack = function() end
		self._state = self._state == "hostile" and "neutral" or self._state or "neutral"
		if self._heart then
			bound[key(self._heart)] = self.object
		end
		eyes(self)
	end,
})
mobs:register_egg(T.CREAKING, S("Creaking"), "cb_mobs_trial_creaking_heart_top_awake.png", 1)
if rawget(_G, "cb_xp") then
	cb_xp.MOB_XP[T.CREAKING] = 0
end

-- Hearts: uprooted (not between logs), dormant (day), awake (night).
local STATES = { "uprooted", "dormant", "awake", }
local function state_node(state)
	return state == "uprooted" and T.HEART or T.HEART .. "_" .. state
end

local function spawn_spot(pos)
	for _ = 1, 5 do
		local x, z = pos.x + math.random(-C.SPAWN_XZ, C.SPAWN_XZ), pos.z + math.random(-C.SPAWN_XZ, C.SPAWN_XZ)
		for y = pos.y + C.SPAWN_Y, pos.y - C.SPAWN_Y, -1 do
			local p = vector.new(x, y, z)
			local below = core.registered_nodes[core.get_node(vector.offset(p, 0, -1, 0)).name]
			if below and below.walkable then
				local ok = true
				for dy = 0, 2 do
					local def = core.registered_nodes[core.get_node(vector.offset(p, 0, dy, 0)).name]
					if not def or def.walkable or (def.liquidtype or "none") ~= "none" then
						ok = false
						break
					end
				end
				if ok then
					return vector.offset(p, 0, -0.5, 0)
				end
				break
			end
		end
	end
	return nil
end

-- Players near pos who may wake a heart (tests replace this).
function C.players_near(pos, r)
	local out = {}
	for _, p in ipairs(core.get_connected_players()) do
		if survivor(p) and vector.distance(p:get_pos(), pos) <= r then
			out[#out + 1] = p
		end
	end
	return out
end

-- One beat of the heart at pos: its state, and a creaking when awake.
function C.heart_tick(pos)
	local node = core.get_node(pos)
	if core.get_item_group(node.name, "creaking_heart") == 0 then
		return false
	end
	local state = not C.between_logs(pos, node) and "uprooted" or C.night() and "awake" or "dormant"
	local want = state_node(state)
	if node.name ~= want then
		core.swap_node(pos, { name = want, param2 = node.param2, })
	end
	local c = C.bound(pos)
	if state == "uprooted" and c then
		C.twitch(c:get_luaentity())
	end
	if state == "awake" and not c and #C.players_near(pos, C.SPAWN_PLAYER) > 0 then
		for _, obj in ipairs(core.get_objects_inside_radius(pos, C.HOME)) do
			local e = obj:get_luaentity()
			if e and e.name == T.CREAKING and e._heart and vector.equals(e._heart, pos) then
				bound[key(pos)] = obj
				return true
			end
		end
		local spot = spawn_spot(pos)
		local obj = spot and core.add_entity(spot, T.CREAKING)
		local e = obj and obj:get_luaentity()
		if e then
			e._heart = vector.copy(pos)
			e.health = 1
			bound[key(pos)] = obj
			core.sound_play("cb_mobs_trial_creaking_unfreeze", { pos = spot, gain = 1, max_hear_distance = 16, }, true)
		end
	end
	if state == "awake" and math.random(6) == 1 then
		core.sound_play("cb_mobs_trial_creaking_heart_beat", { pos = pos, gain = 0.4, max_hear_distance = 12, }, true)
	end
	return true
end

local function destroyed(pos)
	local c = C.bound(pos)
	if c then
		C.twitch(c:get_luaentity())
	end
	bound[key(pos)] = nil
end

for i, state in ipairs(STATES) do
	core.register_node(state_node(state), {
		description = S("Creaking Heart"),
		tiles = { "cb_mobs_trial_creaking_heart_top_" .. state .. ".png", "cb_mobs_trial_creaking_heart_top_" .. state .. ".png",
			"cb_mobs_trial_creaking_heart_side_" .. state .. ".png", },
		paramtype2 = "facedir",
		is_ground_content = false,
		light_source = state == "awake" and 4 or 0,
		groups = { choppy = 2, creaking_heart = i, not_in_creative_inventory = i > 1 and 1 or nil, },
		sounds = default.node_sound_wood_defaults(),
		drop = { max_items = 1, items = { { items = { CLUMP .. " 3", }, rarity = 3, }, { items = { CLUMP .. " 2", }, rarity = 2, },
			{ items = { CLUMP, }, }, }, },
		on_place = core.rotate_node,
		on_construct = function(pos)
			core.get_node_timer(pos):start(1)
		end,
		on_timer = function(pos)
			return C.heart_tick(pos)
		end,
		after_dig_node = function(pos, _, oldmeta, digger)
			destroyed(pos)
			if oldmeta.fields and oldmeta.fields.natural == "1" and digger and digger:is_player()
					and rawget(_G, "cb_xp") then
				cb_xp.drop(pos, math.random(20, 24))
			end
		end,
		on_blast = function(pos)
			destroyed(pos)
			core.remove_node(pos)
		end,
	})
end

core.register_lbm({
	label = "Start creaking heart timers",
	name = "cb_mobs_trial:creaking_heart_timer",
	nodenames = { "group:creaking_heart", },
	run_at_every_load = true,
	action = function(pos)
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then
			timer:start(1)
		end
	end,
})

core.register_craft({ output = T.HEART, recipe = { { LOG, }, { "cb_blocks:resin_block", }, { LOG, }, }, })
