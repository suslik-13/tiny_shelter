-- The wither (spec cycle 4, 8d): a boss summoned by players (skull.lua).
-- It grows for 10 s, unhurt, then blows up. Players have no ranged weapons,
-- so it hovers just above its target, in reach of a sword, and shoots
-- skulls: 8 damage and wither II for 10 s, every 4th skull a slow blue one.
-- Its side heads shoot at other creatures nearby. Below half health it
-- puts on armour, comes down, blows up once more and calls three wither
-- skeletons. Its blasts and skulls break blocks only where the player who
-- summoned it may build, never unbreakable ones. With no player within 64
-- it heals. Drops a nether star and 50 experience. A raw entity with its
-- own slow tick, like the ender dragon: cheap on weak servers.
local S = cb_mobs_nether.S
local N = cb_mobs_nether
N.WITHER, N.NETHER_STAR = "cb_mobs_nether:wither", "cb_mobs_nether:nether_star"
N.WITHER_SKULL_SHOT, N.WITHER_SKULL_BLUE = "cb_mobs_nether:wither_skull_shot", "cb_mobs_nether:wither_skull_blue"
local W = {
	HP = 600, GROW = 10, TICK = 0.25, BOOM = 7, SKULL_DAMAGE = 8, WITHER_LEVEL = 2, WITHER_TIME = 10,
	HOVER = 2, ORBIT = 3, SPEED = 5, RANGE = 64, FIRE_EVERY = 1, BLUE_EVERY = 4, SIDE_EVERY = 2.5,
	SIDE_RANGE = 16, SKULL_SPEED = 12, BLUE_SPEED = 6, SKELETONS = 3, XP = 50, LAND_TIME = 8,
	BAR_COLOR = "#b040ff",
}
N.wither = W
local TEX, ARMOR = "cb_mobs_nether_wither.png", "cb_mobs_nether_wither_armor.png"
local BOOM_SOUND = core.get_modpath("tnt") and "tnt_explode"
local active = {}

core.register_craftitem(N.NETHER_STAR, { description = S("Nether Star"),
	inventory_image = "cb_mobs_nether_nether_star.png", wield_image = "cb_mobs_nether_nether_star.png", })

-- Whether a wither blast set off for `summoner` may break the node at p.
function N.wither_can_break(p, summoner)
	local name = core.get_node(p).name
	if name == "air" or name == "ignore" then
		return false
	end
	local def = core.registered_nodes[name]
	if not def or def.diggable == false or (def.groups and (def.groups.unbreakable or def.groups.immortal))
		or (def.liquidtype and def.liquidtype ~= "none") then
		return false
	end
	if core.is_protected(p, summoner or "") then
		return false
	end
	if def.can_dig and not def.on_blast then
		local ok, res = pcall(def.can_dig, p, nil)
		if not ok or res == false then
			return false
		end
	end
	return true
end

-- Breaks what it may in a ball of radius r; 1 node in 4 drops its items.
function N.wither_break(pos, r, summoner)
	local c, n = vector.round(pos), 0
	for x = -r, r do
		for y = -r, r do
			for z = -r, r do
				if x * x + y * y + z * z <= r * r + r then
					local p = vector.offset(c, x, y, z)
					if N.wither_can_break(p, summoner) then
						local node = core.get_node(p)
						local def = core.registered_nodes[node.name]
						if def.on_blast then
							def.on_blast(p, r)
						else
							core.remove_node(p)
							if math.random(4) == 1 then
								for _, item in ipairs(core.get_node_drops(node, "")) do
									core.add_item(p, item)
								end
							end
						end
						n = n + 1
					end
				end
			end
		end
	end
	return n
end

-- An explosion of the given power: hurts creatures within 2 * power
-- (Minecraft's falloff; armour counts), pushes players, breaks blocks.
function N.wither_boom(pos, power, summoner, source)
	local reach = 2 * power
	for _, obj in ipairs(core.get_objects_inside_radius(pos, reach)) do
		local e = obj:get_luaentity()
		if obj ~= source and (obj:is_player() or (e and e._cmi_is_mob)) then
			local op = obj:get_pos()
			local impact = 1 - vector.distance(pos, op) / reach
			local dmg = math.floor((impact * impact + impact) / 2 * 7 * power + 1)
			obj:punch(source or obj, 1, { full_punch_interval = 1, damage_groups = { fleshy = dmg, }, },
				vector.direction(pos, op))
			if obj:is_player() then
				obj:add_velocity(vector.multiply(vector.direction(pos, op), impact * power * 2))
			end
		end
	end
	if BOOM_SOUND then
		core.sound_play(BOOM_SOUND, { pos = pos, gain = power > 2 and 1.5 or 0.5,
			max_hear_distance = power > 2 and 64 or 16, }, true)
	end
	core.add_particlespawner({
		amount = power > 2 and 48 or 6, time = 0.4, minpos = vector.offset(pos, -power / 2, -power / 2, -power / 2),
		maxpos = vector.offset(pos, power / 2, power / 2, power / 2), minvel = vector.new(-1, 0, -1),
		maxvel = vector.new(1, 2, 1), minexptime = 0.6, maxexptime = 1.4, minsize = 4, maxsize = 9,
		texture = "cb_mobs_nether_wither_projectile.png^[verticalframe:6:0^[colorize:#202020:200",
	})
	return N.wither_break(pos, math.max(1, math.floor(power * 0.75 + 0.5)), summoner)
end

-- A skull hits a player or a creature: 8 damage, and players wither.
function N.wither_skull_hit(skull, obj)
	obj:punch(skull.object, 1, { full_punch_interval = 1, damage_groups = { fleshy = W.SKULL_DAMAGE, }, }, nil)
	local E = cb_core.effects
	if obj:is_player() and E and E.defs.wither then
		E.apply(obj, "wither", W.WITHER_LEVEL, W.WITHER_TIME)
	end
end

local function frames(tex)
	local t = {}
	for i = 0, 5 do
		t[#t + 1] = tex .. "^[verticalframe:6:" .. i
	end
	return t
end

for name, tex in pairs({ [N.WITHER_SKULL_SHOT] = "cb_mobs_nether_wither_projectile.png",
	[N.WITHER_SKULL_BLUE] = "cb_mobs_nether_wither_projectile_strong.png", }) do
	mobs:register_arrow(name, {
		visual = "cube", visual_size = { x = 0.35, y = 0.35, }, textures = frames(tex),
		collisionbox = { -0.15, -0.15, -0.15, 0.15, 0.15, 0.15, }, velocity = W.SKULL_SPEED, lifetime = 6, glow = 4,
		hit_player = N.wither_skull_hit,
		hit_mob = N.wither_skull_hit,
		hit_node = function(self, pos)
			N.wither_boom(pos, 1, self._summoner)
		end,
	})
end

local function shoot(self, from, at, blue)
	local obj = core.add_entity(from, blue and N.WITHER_SKULL_BLUE or N.WITHER_SKULL_SHOT)
	if not obj then
		return nil
	end
	local e = obj:get_luaentity()
	e.owner_id, e._summoner = tostring(self.object), self._summoner
	obj:set_velocity(vector.multiply(vector.direction(from, at), blue and W.BLUE_SPEED or W.SKULL_SPEED))
	core.sound_play("cb_mobs_nether_wither_shot", { pos = from, max_hear_distance = 32, }, true)
	return obj
end

local function targetable(p)
	return p:get_hp() > 0 and not core.is_creative_enabled(p:get_player_name())
end

-- The nearest player it fights, and whether any player is within RANGE.
function W.nearest(pos)
	local best, bd, any = nil, W.RANGE, false
	for _, p in ipairs(core.get_connected_players()) do
		local d = vector.distance(pos, p:get_pos())
		if d <= W.RANGE then
			any = true
			if d < bd and targetable(p) then
				best, bd = p, d
			end
		end
	end
	return best, any
end

W.find_target = W.nearest

-- Something for a side head: a player or a living mob, not undead kin.
local KIN = { [N.WITHER] = true, [N.WITHER_SKELETON] = true, }
local function side_target(pos, main)
	local list = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, W.SIDE_RANGE)) do
		local e = obj:get_luaentity()
		if obj ~= main and ((obj:is_player() and targetable(obj))
			or (e and e._cmi_is_mob and not KIN[e.name] and (e.health or 0) > 0)) then
			list[#list + 1] = obj
		end
	end
	return #list > 0 and list[math.random(#list)] or nil
end

local function spawn_skeletons(pos)
	local n = 0
	for _ = 1, W.SKELETONS * 4 do
		if n >= W.SKELETONS then
			break
		end
		local p = vector.round(vector.offset(pos, math.random(-4, 4), 0, math.random(-4, 4)))
		local free = true
		for dy = 0, 2 do
			local def = core.registered_nodes[core.get_node(vector.offset(p, 0, dy, 0)).name]
			free = free and def and not def.walkable
		end
		if free and core.add_entity(p, N.WITHER_SKELETON) then
			n = n + 1
		end
	end
	return n
end

local function bar(self, pos)
	local B = cb_core.bossbar
	if not B then
		return
	end
	local frac = self._grow > 0 and 1 - self._grow / W.GROW or self.object:get_hp() / W.HP
	for _, p in ipairs(core.get_connected_players()) do
		if vector.distance(pos, p:get_pos()) <= W.RANGE then
			B.show(p, "wither", S("Wither"), frac, W.BAR_COLOR)
		end
	end
end

local function set_look(self)
	self.object:set_properties({ textures = { TEX, self._phase == 2 and ARMOR or "blank.png", }, })
end

local function grow(self, pos, dt)
	self._grow = self._grow - dt
	self.object:set_yaw(self._grow * math.pi)
	self.object:set_velocity(vector.zero())
	if self._grow > 0 then
		self.object:set_texture_mod("^[colorize:#ffffff:" .. (64 + math.floor(self._grow / W.GROW * 160)))
		return
	end
	self._grow = 0
	self.object:set_texture_mod("")
	self.object:set_armor_groups({ fleshy = 100, })
	set_look(self)
	N.wither_boom(pos, W.BOOM, self._summoner, self.object)
end

-- Comes down in the second phase; true once on the ground.
local function land(self, pos, dt)
	self._land_t = (self._land_t or 0) + dt
	local below = vector.round(vector.offset(pos, 0, -0.6, 0))
	local under = core.registered_nodes[core.get_node(below).name]
	if (under and under.walkable) or self._land_t > W.LAND_TIME then
		self.object:set_velocity(vector.zero())
		if under and under.walkable then
			self.object:set_pos(vector.new(pos.x, below.y + 0.5, pos.z))
		end
		return true
	end
	self.object:set_velocity(vector.new(0, -4, 0))
	return false
end

local function move(self, pos, target, dt)
	local tp = target:get_pos()
	local away = vector.new(pos.x - tp.x, 0, pos.z - tp.z)
	if vector.length(away) < 0.1 then
		away = vector.new(1, 0, 0)
	end
	local want = vector.add(tp, vector.multiply(vector.normalize(away), W.ORBIT))
	want.y = tp.y + (self._phase == 2 and 0 or W.HOVER)
	local d = vector.distance(pos, want)
	self.object:set_velocity(d < 0.3 and vector.zero()
		or vector.multiply(vector.direction(pos, want), math.min(W.SPEED, d / dt)))
	self.object:set_yaw(core.dir_to_yaw(vector.direction(pos, tp)))
end

local function head(pos, yaw, side)
	local dir = core.yaw_to_dir(yaw + side * math.pi / 2)
	return vector.add(vector.offset(pos, 0, side == 0 and 3.6 or 3.2, 0), vector.multiply(dir, side == 0 and 0 or 1.3))
end

local function fight(self, pos, target, dt)
	self._fire = self._fire - dt
	local tp = vector.offset(target:get_pos(), 0, 1, 0)
	if self._fire <= 0 then
		local from = head(pos, self.object:get_yaw(), 0)
		if core.line_of_sight(from, tp) or vector.distance(from, tp) < 4 then
			self._shots = self._shots + 1
			local blue = self._shots % W.BLUE_EVERY == 0
			shoot(self, vector.add(from, vector.multiply(vector.direction(from, tp), 0.8)), tp, blue)
			self._fire = W.FIRE_EVERY * (blue and 2 or 1) * (self._phase == 2 and 1.5 or 1)
		else
			self._fire = 0.5
		end
	end
end

local function sides(self, pos, main, dt)
	self._side = self._side - dt
	if self._side > 0 then
		return
	end
	self._side = W.SIDE_EVERY + math.random()
	local t = side_target(pos, main)
	if t then
		local from = head(pos, self.object:get_yaw(), math.random(2) == 1 and 1 or -1)
		shoot(self, from, vector.offset(t:get_pos(), 0, 0.8, 0), false)
	end
end

-- Inside blocks it breaks its way out (where the summoner may build).
local function unstuck(self, pos)
	for dy = 0, 3 do
		local def = core.registered_nodes[core.get_node(vector.offset(pos, 0, dy, 0)).name]
		if def and def.walkable then
			N.wither_break(vector.offset(pos, 0, 1.5, 0), 2, self._summoner)
			return true
		end
	end
	return false
end

local function step(self, dtime)
	self._tick = self._tick + dtime
	if self._tick < W.TICK then
		return
	end
	local dt = self._tick
	self._tick = 0
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	self._bar = self._bar + dt
	if self._bar >= 0.5 then
		self._bar = 0
		bar(self, pos)
	end
	if self._grow > 0 then
		return grow(self, pos, dt)
	end
	self._sec = self._sec + dt
	local target, anyone = W.find_target(pos)
	if self._sec >= 1 then
		self._sec = self._sec - 1
		local hp = self.object:get_hp()
		if not anyone and hp < W.HP then
			self.object:set_hp(hp + 1)
		end
		unstuck(self, pos)
	end
	if self._phase == 1 and self.object:get_hp() <= W.HP / 2 then
		self._phase, self._landing, self._land_t = 2, true, 0
		set_look(self)
	end
	if self._landing then
		if land(self, pos, dt) then
			self._landing = false
			N.wither_boom(pos, W.BOOM, self._summoner, self.object)
			spawn_skeletons(pos)
		end
		return
	end
	if target then
		move(self, pos, target, dt)
		fight(self, pos, target, dt)
	else
		self.object:set_velocity(vector.zero())
	end
	sides(self, pos, target, dt)
end

core.register_entity(N.WITHER, {
	initial_properties = {
		hp_max = W.HP,
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.9, 0.6, -0.9, 0.9, 4, 0.9, },
		selectionbox = { -0.9, 0.6, -0.9, 0.9, 4, 0.9, },
		visual = "mesh",
		mesh = "cb_mobs_nether_wither.b3d",
		textures = { "cb_mobs_nether_wither_invulnerable.png", "blank.png", },
		visual_size = { x = 6, y = 6, },
		static_save = true,
		glow = 2,
	},
	on_activate = function(self, staticdata)
		if core.settings:get_bool("only_peaceful_mobs", false) then
			self.object:remove()
			return
		end
		local data = core.deserialize(staticdata or "") or {}
		self._summoner, self._grow, self._phase = data.summoner or "", data.grow or W.GROW, data.phase or 1
		self._landing = data.landing
		self._tick, self._sec, self._bar, self._fire, self._side, self._shots = 0, 0, 0, W.FIRE_EVERY, W.SIDE_EVERY, 0
		if self._grow > 0 then
			self.object:set_armor_groups({ immortal = 1, })
		else
			self.object:set_armor_groups({ fleshy = 100, })
			set_look(self)
		end
		self.object:set_animation({ x = 20, y = 40, }, 12, 0, true)
		active[self] = true
	end,
	on_deactivate = function(self)
		active[self] = nil
	end,
	get_staticdata = function(self)
		return core.serialize({ summoner = self._summoner, grow = self._grow, phase = self._phase,
			landing = self._landing, })
	end,
	on_punch = function(self)
		if self._grow > 0 then
			return true
		end
		core.sound_play("cb_mobs_nether_skeleton_hurt", { object = self.object, max_hear_distance = 32, pitch = 0.6, },
			true)
	end,
	on_death = function(self)
		active[self] = nil
		local pos = self.object:get_pos()
		core.sound_play("cb_mobs_nether_wither_spawn", { pos = pos, pitch = 0.7, max_hear_distance = 128, }, true)
		core.add_item(vector.offset(pos, 0, 1, 0), N.NETHER_STAR)
		if rawget(_G, "cb_xp") and cb_xp.drop then
			cb_xp.drop(vector.offset(pos, 0, 1, 0), W.XP)
		end
	end,
	on_step = step,
})

-- Summons a wither at pos for player `name` ("" for none).
function N.spawn_wither(pos, name)
	local obj = core.add_entity(pos, N.WITHER, core.serialize({ summoner = name or "", }))
	if not obj or not obj:get_pos() then
		return nil
	end
	core.sound_play("cb_mobs_nether_wither_spawn", { pos = pos, gain = 1.0, max_hear_distance = 128, }, true)
	return obj
end

function W.count()
	local n = 0
	for ent in pairs(active) do
		n = n + (ent.object:get_pos() and 1 or 0)
	end
	return n
end
