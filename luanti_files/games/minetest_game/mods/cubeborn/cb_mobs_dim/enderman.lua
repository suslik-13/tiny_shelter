-- Enderman: neutral, angered by a player who looks at its head. The look
-- check is one globalstep every 0.5 s over a registry of active endermen
-- (no object searches); the raycast runs only once the angle matches.
local S = cb_mobs_dim.S

local NAME = "cb_mobs_dim:enderman"
local HEAD = 2.55
local LOOK_RANGE = 32
local LOOK_INTERVAL = 0.5
cb_mobs_dim.HEAD = HEAD
cb_mobs_dim.LOOK_RANGE = LOOK_RANGE

-- luaentity -> true for every active enderman
local active = {}
cb_mobs_dim.active = active

local BODY = "cb_mobs_dim_enderman.png^cb_mobs_dim_enderman_eyes.png"

local function tile_name(t)
	if type(t) == "string" then
		return t
	elseif type(t) == "table" then
		return t.name or t.image
	end
end

-- The Mineclonia mesh has 9 texture slots: a flower at 90 and at 45 degrees,
-- the six faces of a held cube (back, bottom, front, left, right, top) and the
-- body.
function cb_mobs_dim.enderman_textures(node)
	local tex = { "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png",
		"blank.png", BODY, }
	local def = node and core.registered_nodes[node]
	if not def then
		return tex
	end
	local tiles = def.tiles or {}
	if def.drawtype == "plantlike" then
		tex[2] = tile_name(tiles[1]) or "unknown_node.png"
	else
		local f, last = {}, "unknown_node.png"
		for i = 1, 6 do
			last = tile_name(tiles[i]) or last
			f[i] = last
		end
		tex[3], tex[4], tex[5], tex[6], tex[7], tex[8] = f[5], f[2], f[6], f[3], f[4], f[1]
	end
	return tex
end

local ANIM_NORMAL = {
	stand_start = 40, stand_end = 80, stand_speed = 25,
	walk_start = 0, walk_end = 40, walk_speed = 25,
	run_start = 0, run_end = 40, run_speed = 50,
	punch_start = 81, punch_end = 120, punch_speed = 50,
}
local ANIM_CARRY = {
	stand_start = 200, stand_end = 200, stand_speed = 25,
	walk_start = 161, walk_end = 200, walk_speed = 25,
	run_start = 161, run_end = 200, run_speed = 50,
	punch_start = 81, punch_end = 120, punch_speed = 50,
}

-- Textures and animations for what the enderman holds (self._carried).
function cb_mobs_dim.set_carried_visual(self)
	local tex = cb_mobs_dim.enderman_textures(self._carried)
	self.base_texture = tex
	self.textures = tex
	self.object:set_properties({ textures = tex, })
	self.animation = table.copy(self._carried and ANIM_CARRY or ANIM_NORMAL)
	self:set_animation("stand", true)
end

-- Does an eye looking along look see head: the angle as in MC, then a
-- raycast for walkable nodes in between.
local function sees(eye, look, head)
	local dx, dy, dz = head.x - eye.x, head.y - eye.y, head.z - eye.z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	if dist < 0.5 or dist > LOOK_RANGE then
		return false
	end
	if (look.x * dx + look.y * dy + look.z * dz) / dist <= 1 - 0.025 / dist then
		return false
	end
	for hit in core.raycast(eye, head, false, false) do
		if hit.type == "node" then
			local def = core.registered_nodes[core.get_node(hit.under).name]
			if not def or def.walkable ~= false then
				return false
			end
		end
	end
	return true
end

local function eye_of(player)
	local eye = player:get_pos()
	eye.y = eye.y + (player:get_properties().eye_height or 1.625)
	return eye
end

function cb_mobs_dim.looks_at(player, head)
	return sees(eye_of(player), player:get_look_dir(), head)
end

-- One pass over players x active endermen; returns how many got angry.
function cb_mobs_dim.look_tick(players)
	local calm, n = {}, 0
	for ent in pairs(active) do
		local pos = ent.object:get_pos()
		if not pos then
			active[ent] = nil
		elseif ent.state ~= "attack" and ent.health > 0 then
			n = n + 1
			pos.y = pos.y + HEAD
			calm[n] = { ent = ent, head = pos, }
		end
	end
	local angered = 0
	for _, player in ipairs(players) do
		local ppos = player:get_pos()
		if n > 0 and ppos and player:get_hp() > 0 then
			local eye, look
			for i = 1, n do
				local c = calm[i]
				local head = c.head
				if c.ent.state ~= "attack"
						and math.abs(head.x - ppos.x) <= LOOK_RANGE and math.abs(head.z - ppos.z) <= LOOK_RANGE
						and math.abs(head.y - ppos.y) <= LOOK_RANGE + HEAD then
					if not eye then
						eye, look = eye_of(player), player:get_look_dir()
					end
					if sees(eye, look, head) then
						c.ent:do_attack(player)
						angered = angered + 1
					end
				end
			end
		end
	end
	return angered
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < LOOK_INTERVAL then
		return
	end
	timer = 0
	if next(active) then
		cb_mobs_dim.look_tick(core.get_connected_players())
	end
end)

-- Teleport: up to TP_TRIES random targets within TP_RANGE, each dropped at
-- most TP_DROP nodes onto loaded walkable ground with three free nodes above,
-- unprotected and in the same pocket (or outside all pockets) as the start.
local TP_RANGE, TP_TRIES, TP_DROP = 32, 8, 8
local floor = math.floor
cb_mobs_dim.rand = math.random

local function loaded_def(p)
	local n = core.get_node_or_nil(p)
	if not n or n.name == "ignore" then
		return nil
	end
	return core.registered_nodes[n.name]
end

local function free(p)
	local def = loaded_def(p)
	return def ~= nil and def.walkable == false and (def.liquidtype or "none") == "none"
		and (def.damage_per_second or 0) <= 0
end

local function pocket_of(p)
	if cb_dimensions then
		local _, pocket = cb_dimensions.is_shell(p)
		return pocket
	end
end

function cb_mobs_dim.teleport_spot(from, rand)
	rand = rand or cb_mobs_dim.rand
	local fx, fy, fz = floor(from.x + 0.5), floor(from.y + 0.5), floor(from.z + 0.5)
	local home = pocket_of(from)
	for _ = 1, TP_TRIES do
		local x = fx + rand(-TP_RANGE, TP_RANGE)
		local y = fy + rand(-TP_RANGE / 2, TP_RANGE / 2)
		local z = fz + rand(-TP_RANGE, TP_RANGE)
		for dy = 0, TP_DROP do
			local def = loaded_def(vector.new(x, y - dy, z))
			if not def then
				break
			end
			if def.walkable ~= false then
				local feet = vector.new(x, y - dy + 1, z)
				if free(feet) and free(vector.new(x, feet.y + 1, z)) and free(vector.new(x, feet.y + 2, z))
						and vector.distance(from, feet) <= TP_RANGE and pocket_of(feet) == home
						and not core.is_protected(feet, "") then
					return vector.new(x, feet.y - 0.5, z)
				end
				break
			end
		end
	end
	return nil
end

function cb_mobs_dim.teleport(ent)
	local from = ent.object:get_pos()
	local to = from and cb_mobs_dim.teleport_spot(from)
	if not to then
		return false
	end
	core.sound_play("cb_mobs_dim_enderman_teleport_src", { pos = from, max_hear_distance = 16, }, true)
	ent.object:set_pos(to)
	core.sound_play("cb_mobs_dim_enderman_teleport_dst", { pos = to, max_hear_distance = 16, }, true)
	return true
end

-- Per-entity timers kept out of staticdata.
local wet_timer = setmetatable({}, { __mode = "k", })

mobs:register_mob(NAME, {
	type = "monster",
	passive = false,
	attack_players = false,
	attack_type = "dogfight",
	hp_min = 40,
	hp_max = 40,
	armor = 100,
	damage = 7,
	reach = 2,
	collisionbox = { -0.3, 0, -0.3, 0.3, 2.9, 0.3, },
	visual = "mesh",
	mesh = "cb_mobs_dim_enderman.b3d",
	visual_size = { x = 3, y = 3, },
	textures = { cb_mobs_dim.enderman_textures(), },
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 3.5,
	view_range = LOOK_RANGE,
	fear_height = 4,
	water_damage = 1,
	sounds = {
		random = "cb_mobs_dim_enderman_random",
		damage = "cb_mobs_dim_enderman_hurt",
		death = "cb_mobs_dim_enderman_death",
		war_cry = "cb_mobs_dim_enderman_scream",
		attack = "mobs_punch",
		distance = 16,
	},
	animation = ANIM_NORMAL,
	drops = {
		{ name = "cb_items:ender_pearl", chance = 1, min = 0, max = 1, },
	},
	-- Projectiles (hits by entities that are not mobs) do no harm: it dodges.
	do_punch = function(self, hitter)
		if hitter and not hitter:is_player() then
			local e = hitter:get_luaentity()
			if e and not e._cmi_is_mob then
				cb_mobs_dim.teleport(self)
				return false
			end
		end
	end,
	do_custom = function(self, dtime)
		local t = (wet_timer[self] or 0) + dtime
		if t >= 0.5 then
			t = 0
			if core.get_item_group(self.standing_in, "water") > 0 then
				cb_mobs_dim.teleport(self)
			end
		end
		wet_timer[self] = t
		if cb_mobs_dim.carry_step then
			cb_mobs_dim.carry_step(self, dtime)
		end
	end,
	on_die = function(self, pos)
		if cb_mobs_dim.carrier_died then
			cb_mobs_dim.carrier_died(self, pos)
		end
	end,
	after_activate = function(self)
		active[self] = true
		if self._carried and not core.registered_nodes[self._carried] then
			self._carried, self._taken_from = nil, nil
		end
		cb_mobs_dim.set_carried_visual(self)
	end,
})

local edef = core.registered_entities[NAME]
-- Neutral: never looks for targets itself (saves an object search per second).
edef.general_attack = function() end
edef.on_deactivate = function(self, removal)
	active[self] = nil
	if cb_mobs_dim.carrier_gone then
		cb_mobs_dim.carrier_gone(self, removal)
	end
end

mobs:register_egg(NAME, S("Enderman"), "default_obsidian.png", 1)
