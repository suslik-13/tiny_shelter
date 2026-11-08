-- Elytra (spec 8), flight ported from Mineclonia (playerphysics/elytra.lua,
-- GPLv3): worn in the torso slot of 3d_armor (held in hand when 3d_armor is
-- missing). Jumping again in the air starts a glide: the player rides an
-- invisible physical glider whose velocity follows Minecraft's fall-flying
-- formulas every server step (diving gains speed, climbing costs it, turning
-- has drag), so the client sees smooth motion. Hitting a wall fast or landing
-- after a long fall hurts; water or the ground ends the flight. A second of
-- flight wears the elytra by 1 of 432; a nearly broken one does not open
-- (repair it on an anvil). Cost: the jump check runs each step only for
-- players who wear elytra; one glider entity per flying player.
local S = cb_items.S
local NAME, GLIDER = "cb_items:elytra_wings", "cb_items:elytra_glider"
local E = {
	DURABILITY = 432, SAFE_FALL = 3, WALL_DAMAGE = 6, JUMP_GAP = 0.1,
	GRAVITY = -1.6, ONE_TICK = 0.05, AIR_DRAG = 0.98, DRAG_HORIZ = 0.99, DRAG_ASCENT = 0.04, ACC_DESCENT = 3.2,
	ROTATION_DRAG = 0.1,
}
cb_items.elytra = E
local wearing, gliders, jumps = {}, {}, {}

function E.set_wearing(name, on)
	wearing[name] = on or nil
end

function E.wearing(name)
	return wearing[name] == true
end

function E.gliding(name)
	local g = gliders[name]
	return g ~= nil and g:get_pos() ~= nil
end

-- Minecraft's fall-flying update over dt seconds (Mineclonia's closed form
-- of the per-tick update; only stable for dt up to a tick or so).
local function flight_step(v, dir, pitch, dtime)
	local horiz = math.sqrt(dir.x * dir.x + dir.z * dir.z)
	local movement = math.sqrt(v.x * v.x + v.z * v.z)
	local incline = math.cos(pitch)
	local v_movement = incline * incline
	local n = dtime / E.ONE_TICK

	local D = E.AIR_DRAG
	local default_b = -0.1 * v_movement
	local a = -E.GRAVITY * (-1.0 + v_movement * 0.75)
	local c = v.y * D ^ n + (a * D * ((D ^ n) - 1)) / (D - 1)
	local b = (c < 0.0 and horiz > 0.0) and default_b or 0
	local a_factor = ((b + 1) * D * ((((b + 1) * D) ^ n) - 1)) / (b * D + D - 1)
	v.y = v.y * (((b + 1) * D) ^ n) + a * a_factor

	D = E.DRAG_HORIZ
	local h_factor = (D * ((D ^ n) - 1)) / (D - 1)
	-- diving speeds up
	if c < 0.0 and horiz > 0.0 then
		v.x = v.x * (D ^ n) + (dir.x * (default_b * c) / horiz) * h_factor
		v.z = v.z * (D ^ n) + (dir.z * (default_b * c) / horiz) * h_factor
	end
	-- climbing trades speed for height
	if horiz > 0.0 and pitch < 0.0 then
		local arrest = movement * -math.sin(pitch) * E.DRAG_ASCENT
		v.x = v.x - dir.x * arrest / horiz * h_factor
		v.y = v.y + arrest * E.ACC_DESCENT * a_factor
		v.z = v.z - dir.z * arrest / horiz * h_factor
	end
	-- turning drags the velocity towards the look direction
	if horiz > 0.0 then
		v.x = v.x + (dir.x / horiz * movement - v.x) * E.ROTATION_DRAG * h_factor
		v.z = v.z + (dir.z / horiz * movement - v.z) * E.ROTATION_DRAG * h_factor
	end
	return v
end

-- The velocity after dtime seconds of flight, in steps of at most a tick
-- (a lagging server gives long steps). v: velocity, dir: look direction,
-- pitch: look vertical (positive = down).
function E.flight_velocity(v, dir, pitch, dtime)
	v = vector.copy(v)
	local steps = math.max(1, math.ceil(dtime / E.ONE_TICK - 1e-6))
	for _ = 1, steps do
		v = flight_step(v, dir, pitch, dtime / steps)
	end
	return v
end

-- Firework boost (Minecraft, per tick in blocks/tick):
-- v <- v + look * 0.1 + (look * 1.5 - v) * 0.5; here in nodes/s, ticks of dtime.
function E.boost_velocity(v, look, dtime)
	v = vector.copy(v)
	local steps = math.max(1, math.ceil(dtime / E.ONE_TICK - 1e-6))
	local k = dtime / steps / E.ONE_TICK -- share of a whole tick per step
	for _ = 1, steps do
		local t = vector.add(vector.multiply(look, 0.1 * 20), vector.multiply(vector.subtract(vector.multiply(look, 1.5 * 20), v), 0.5))
		v = vector.add(v, vector.multiply(t, k))
	end
	return v
end

local boosts = {}

-- A rocket used in flight: `seconds` of boost; its stars burst at the end
-- around the flyer (and hurt, as in Minecraft).
function E.boost(player, seconds, stars)
	boosts[player:get_player_name()] = { left = seconds, stars = stars or {}, }
end

function E.boosting(name)
	local b = boosts[name]
	return b ~= nil and b.left > 0
end

-- Jump presses since the player last stood still: the glide opens on the
-- second (the first is the jump itself). st: per-player state, now in seconds.
function E.count_jump(st, jump, vel_y, now)
	if vel_y == 0 and not jump then
		st.count = 0
	elseif jump and not st.held and now - (st.last or -1) > E.JUMP_GAP then
		st.count, st.last = (st.count or 0) + 1, now
	end
	st.held = jump
	return st.count or 0
end

-- The worn elytra stack and its 3d_armor slot, if any.
local function worn(player)
	if not (rawget(_G, "armor") and armor.get_valid_player) then
		local stack = player:get_wielded_item()
		return stack:get_name() == NAME and stack or nil, nil
	end
	local _, inv = armor:get_valid_player(player, "[cb_items]")
	if not inv then
		return nil
	end
	for i, stack in ipairs(inv:get_list("armor") or {}) do
		if stack:get_name() == NAME then
			return stack, i
		end
	end
end

local WEAR = math.ceil(65535 / E.DURABILITY)

-- Uses left before the elytra stops opening.
function E.uses_left(stack)
	return math.floor((65535 - stack:get_wear()) / WEAR)
end

local function wear(player, seconds)
	if core.is_creative_enabled(player:get_player_name()) then
		return true
	end
	local stack, i = worn(player)
	if not stack then
		return false
	end
	stack:add_wear(math.min(WEAR * seconds, 65535 - stack:get_wear() - 1))
	if i then
		armor:set_inventory_stack(player, i, stack)
	else
		player:set_wielded_item(stack)
	end
	return E.uses_left(stack) > 1
end

local function grounded(pos)
	local def = core.registered_nodes[core.get_node(vector.round(vector.offset(pos, 0, -0.1, 0))).name]
	return def == nil or def.walkable ~= false
end

local function in_liquid(pos)
	local def = core.registered_nodes[core.get_node(vector.round(vector.offset(pos, 0, 0.2, 0))).name]
	return def ~= nil and (def.liquidtype or "none") ~= "none"
end

local function pose(player, flying)
	local api = rawget(_G, "player_api")
	if not api then
		return
	end
	local name = player:get_player_name()
	api.player_attached[name] = flying or nil
	local model = api.registered_models and api.registered_models[api.get_animation(player).model or ""]
	local anims = model and model.animations or {}
	api.set_animation(player, flying and (anims.fly and "fly" or "lay") or "stand", 30)
end

function E.stop(player)
	local name = player:get_player_name()
	boosts[name] = nil
	local g = gliders[name]
	gliders[name] = nil
	if not g then
		return
	end
	local v = g:get_velocity()
	if player:get_attach() == g then
		player:set_detach()
	end
	pose(player, false)
	if v then
		player:add_velocity(v)
	end
	g:remove()
end

function E.start(player)
	local name = player:get_player_name()
	local stack = worn(player)
	if not stack then
		return false
	end
	if not core.is_creative_enabled(name) and E.uses_left(stack) <= 1 then
		core.chat_send_player(name, S("The elytra is broken; repair it on an anvil."))
		return false
	end
	local pos = player:get_pos()
	local obj = core.add_entity(pos, GLIDER)
	if not obj then
		return false
	end
	local g = obj:get_luaentity()
	g.driver, g._last_y = player, pos.y
	obj:set_velocity(player:get_velocity())
	player:set_attach(obj, "", vector.zero(), vector.zero())
	gliders[name] = obj
	pose(player, true)
	core.sound_play("cb_items_throw", { pos = pos, max_hear_distance = 12, }, true)
	return true
end

local function hurt(player, amount, kind)
	if amount >= 1 and player:get_hp() > 0 then
		player:set_hp(player:get_hp() - math.floor(amount), { type = "set_hp", cause = kind, })
	end
end

core.register_entity(GLIDER, {
	initial_properties = {
		visual = "sprite", textures = { "blank.png", }, visual_size = { x = 0, y = 0, },
		collisionbox = { -0.3, 0, -0.3, 0.3, 0.6, 0.3, }, pointable = false, physical = true,
		collide_with_objects = false, static_save = false,
	},
	on_activate = function(self)
		self._wear_t, self._fall, self._immune = 0, 0, 0
	end,
	on_step = function(self, dtime, moveresult)
		local p = self.driver
		local pos = self.object:get_pos()
		if not (p and p:get_pos() and pos) or p:get_attach() ~= self.object then
			if p and p.get_player_name and gliders[p:get_player_name()] == self.object then
				gliders[p:get_player_name()] = nil
				pose(p, false)
			end
			self.object:remove()
			return
		end
		local name = p:get_player_name()
		if not wearing[name] or in_liquid(pos) or p:get_hp() <= 0 then
			return E.stop(p)
		end
		self._wear_t = self._wear_t + dtime
		if self._wear_t >= 1 then
			self._wear_t = self._wear_t - 1
			if not wear(p, 1) then
				return E.stop(p)
			end
		end
		self._immune = math.max(0, self._immune - 1)
		self._fall = math.max(0, self._fall + (self._last_y - pos.y))
		self._last_y = pos.y
		local v = self.object:get_velocity()
		if v.y > -10 and self._fall > 1 then
			self._fall = 1
		end
		for _, c in ipairs(moveresult and moveresult.collisions or {}) do
			-- not against unloaded map (ignore stops gliders too)
			if (c.axis == "x" or c.axis == "z") and self._immune == 0
					and not (c.type == "node" and core.get_node(c.node_pos).name == "ignore") then
				local diff = math.abs(vector.length(c.old_velocity) - vector.length(c.new_velocity))
				if diff >= E.WALL_DAMAGE then
					hurt(p, diff * 0.5, "cb_elytra_wall")
					self._immune = 10
				end
			end
		end
		if moveresult and moveresult.touching_ground then
			hurt(p, self._fall - E.SAFE_FALL, "fall")
			return E.stop(p)
		end
		local pitch, yaw = p:get_look_vertical(), p:get_look_horizontal()
		self.object:set_rotation(vector.new(-pitch, yaw, 0))
		local nv = E.flight_velocity(v, p:get_look_dir(), pitch, dtime)
		local b = boosts[name]
		if b then
			nv = E.boost_velocity(nv, p:get_look_dir(), math.min(dtime, b.left))
			b.left = b.left - dtime
			if b.left <= 0 then
				boosts[name] = nil
				local F = cb_items.fireworks
				if F and #b.stars > 0 then
					F.explode(pos, b.stars)
				end
			end
		end
		self.object:set_velocity(nv)
	end,
})

local def = {
	description = S("Elytra"),
	inventory_image = "cb_items_inv_elytra_wings.png",
	texture = "cb_items_elytra_wings.png",
	preview = "cb_items_elytra_wings_preview.png",
	groups = { armor_torso = 1, armor_heal = 0, armor_use = 0, },
	armor_groups = { fleshy = 0, },
}
if rawget(_G, "armor") and armor.register_armor then
	armor:register_armor(NAME, def)
	armor:register_on_equip(function(player, _, stack)
		if stack:get_name() == NAME then
			E.set_wearing(player:get_player_name(), true)
		end
	end)
	armor:register_on_unequip(function(player, _, stack)
		if stack:get_name() == NAME then
			E.set_wearing(player:get_player_name(), false)
		end
	end)
	core.register_on_joinplayer(function(player)
		local _, inv = armor:get_valid_player(player, "[cb_items]")
		if inv and inv:contains_item("armor", NAME) then
			E.set_wearing(player:get_player_name(), true)
		end
	end)
else
	core.register_tool(NAME, { description = def.description, inventory_image = def.inventory_image, })
end

local hand = not (rawget(_G, "armor") and armor.register_armor)
core.register_globalstep(function()
	local now = core.get_us_time() / 1e6
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if hand then
			E.set_wearing(name, player:get_wielded_item():get_name() == NAME)
		end
		if wearing[name] and not gliders[name] and not player:get_attach() then
			local st = jumps[name] or {}
			jumps[name] = st
			local n = E.count_jump(st, player:get_player_control().jump, player:get_velocity().y, now)
			if n >= 2 and not grounded(player:get_pos()) then
				st.count = 0
				E.start(player)
			end
		elseif not wearing[name] then
			jumps[name] = nil
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	E.stop(player)
	wearing[name], jumps[name] = nil, nil
end)

core.register_on_dieplayer(function(player)
	E.stop(player)
end)
